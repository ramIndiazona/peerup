import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  CallReaction,
  FriendRequest,
  FriendRequestStatus,
  Notification,
  NotificationType,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeEventsService } from '../realtime/realtime-events.service';
import { SubmitCallFeedbackDto } from './dto/submit-call-feedback.dto';
import { PresenceService } from 'src/presence/presence.service';

type SideEffects = {
  notifications: { userId: string; notification: Notification }[];
  events: { userId: string; event: string; payload: Record<string, unknown> }[];
};

type RequestOutcome = {
  status: 'FRIENDS' | 'PENDING';
  message: string;
  request: FriendRequest;
  sideEffects: SideEffects;
};

type SendRequestResult = {
  status: 'FRIENDS' | 'PENDING';
  message: string;
  request: FriendRequest;
};

const emptySideEffects = (): SideEffects => ({
  notifications: [],
  events: [],
});

@Injectable()
export class FriendRequestsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: RealtimeEventsService,
      private readonly presence: PresenceService,
  ) { }

  private async lockPair(
    tx: Prisma.TransactionClient,
    userAId: string,
    userBId: string,
  ): Promise<void> {
    // Serialize all friendship mutations for the same pair across processes.
    // hashtext collisions only over-serialize unrelated pairs; they are safe.
    const [first, second] = [userAId, userBId].sort();
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${first}), hashtext(${second}))`;
  }

  private async ensureNotBlocked(
    userAId: string,
    userBId: string,
    client?: Prisma.TransactionClient,
  ): Promise<void> {
    const db = client ?? (this.prisma as unknown as Prisma.TransactionClient);
    const block = await db.block.findFirst({
      where: {
        OR: [
          { blockerId: userAId, blockedId: userBId },
          { blockerId: userBId, blockedId: userAId },
        ],
      },
      select: { id: true },
    });

    if (block) {
      throw new ForbiddenException(
        'Friend requests are unavailable between these users.',
      );
    }
  }

  private async persistNotification(
    tx: Prisma.TransactionClient,
    userId: string,
    title: string,
    body: string,
    data: Record<string, unknown>,
  ): Promise<Notification> {
    // Save in-app notification only. Do not send an FCM push alert.
    return tx.notification.create({
      data: {
        userId,
        type: NotificationType.SYSTEM,
        title,
        body,
        data: data as Prisma.InputJsonValue,
      },
    });
  }

  private async resolveFriendRequestNotification(
    tx: Prisma.TransactionClient,
    requestId: string,
    kind: string,
    senderId: string,
  ): Promise<void> {
    // The notification action must disappear once the request is no longer
    // pending, including after an app restart or notification refresh.
    await tx.notification.updateMany({
      where: {
        type: NotificationType.SYSTEM,
        data: { path: ['requestId'], equals: requestId },
      },
      data: {
        data: {
          kind,
          requestId,
          senderId,
        } as Prisma.InputJsonValue,
      },
    });
  }

  private async dispatchSideEffects(effects: SideEffects): Promise<void> {
    // Persistence already committed. Only now emit realtime events.
    for (const item of effects.notifications) {
      await this.events.sendToUser(item.userId, 'NOTIFICATION_CREATED', {
        notification: item.notification,
      });
    }
    for (const item of effects.events) {
      await this.events.sendToUser(item.userId, item.event, item.payload);
    }
  }

  private async cancelOtherPendingRequests(
    tx: Prisma.TransactionClient,
    acceptedRequestId: string,
    userAId: string,
    userBId: string,
  ): Promise<void> {
    const others = await tx.friendRequest.findMany({
      where: {
        id: { not: acceptedRequestId },
        status: FriendRequestStatus.PENDING,
        OR: [
          { senderId: userAId, receiverId: userBId },
          { senderId: userBId, receiverId: userAId },
        ],
      },
      select: { id: true, senderId: true },
    });

    if (others.length === 0) return;

    await tx.friendRequest.updateMany({
      where: {
        id: { in: others.map((request) => request.id) },
        status: FriendRequestStatus.PENDING,
      },
      data: { status: FriendRequestStatus.CANCELLED },
    });

    for (const other of others) {
      await this.resolveFriendRequestNotification(
        tx,
        other.id,
        'FRIEND_REQUEST_ACCEPTED',
        other.senderId,
      );
    }
  }

  private normalizeReaction(reaction?: string | null): CallReaction | null {
    if (!reaction) return null;
    switch (reaction.toUpperCase()) {
      case 'LIKE':
        return CallReaction.LIKE;
      case 'DISLIKE':
        return CallReaction.DISLIKE;
      default:
        throw new BadRequestException(
          'Reaction must be LIKE or DISLIKE.',
        );
    }
  }

  private async resolveCallSessionId(
    senderId: string,
    receiverId: string,
    callId?: string,
  ): Promise<string | null> {
    const pair = [
      { userAId: senderId, userBId: receiverId },
      { userAId: receiverId, userBId: senderId },
    ];

    if (callId) {
      const call = await this.prisma.callSession.findFirst({
        where: { id: callId, OR: pair },
        select: { id: true },
      });
      if (!call) {
        throw new BadRequestException('Invalid call session.');
      }
      return call.id;
    }

    // The Flutter call-feedback payload does not include a call id. Use the
    // most recent call between the pair so feedback retries remain idempotent.
    const latest = await this.prisma.callSession.findFirst({
      where: { OR: pair },
      orderBy: { createdAt: 'desc' },
      select: { id: true },
    });
    return latest?.id ?? null;
  }

  async submitCallFeedback(userId: string, dto: SubmitCallFeedbackDto) {
    if (userId === dto.receiverId) {
      throw new BadRequestException(
        'You cannot submit feedback for yourself.',
      );
    }

    const receiver = await this.prisma.user.findUnique({
      where: { id: dto.receiverId },
      select: { id: true },
    });
    if (!receiver) {
      throw new NotFoundException('User not found.');
    }

    await this.ensureNotBlocked(userId, dto.receiverId);

    const reaction = this.normalizeReaction(dto.reaction);
    const feedbackItems = [
      ...new Set(
        (dto.feedback ?? [])
          .map((item) => item.trim())
          .filter((item) => item.length > 0),
      ),
    ];
    const addToFriends = dto.addToFriends ?? false;
    const connectAgain = dto.connectAgain ?? false;
    const callSessionId = await this.resolveCallSessionId(
      userId,
      dto.receiverId,
      dto.callId,
    );

    // Stable key: one feedback row per sender per call session. When no call
    // session exists, fall back to one row per sender/receiver pair.
    const dedupeKey = callSessionId
      ? `call:${callSessionId}:${userId}`
      : `pair:${[userId, dto.receiverId].sort().join(':')}:${userId}`;

    const feedback = await this.prisma.callFeedback.upsert({
      where: { dedupeKey },
      update: {
        reaction,
        feedback: feedbackItems,
        addToFriends,
        connectAgain,
        callSessionId,
      },
      create: {
        dedupeKey,
        senderId: userId,
        receiverId: dto.receiverId,
        callSessionId,
        reaction,
        feedback: feedbackItems,
        addToFriends,
        connectAgain,
      },
    });

    let friendResult: SendRequestResult | null = null;
    if (addToFriends) {
      friendResult = await this.sendRequest(userId, dto.receiverId);
    }

    let status = 'FEEDBACK_SUBMITTED';
    let message = 'Feedback submitted.';
    if (friendResult) {
      status = friendResult.status;
      message =
        friendResult.status === 'FRIENDS'
          ? friendResult.message
          : `Feedback submitted. ${friendResult.message}`;
    }

    return {
      status,
      message,
      feedback,
      ...(friendResult ? { request: friendResult.request } : {}),
    };
  }

  async sendRequest(
    senderId: string,
    receiverId: string,
  ): Promise<SendRequestResult> {
    if (senderId === receiverId) {
      throw new BadRequestException(
        'You cannot send a friend request to yourself.',
      );
    }

    const [receiver, sender] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: receiverId },
        select: { id: true, profile: { select: { name: true } } },
      }),
      this.prisma.user.findUnique({
        where: { id: senderId },
        select: { id: true, profile: { select: { name: true } } },
      }),
    ]);

    if (!receiver) {
      throw new NotFoundException('User not found.');
    }

    const senderName = sender?.profile?.name ?? 'Someone';
    const receiverName = receiver.profile?.name ?? 'Someone';

    const outcome = await this.prisma.$transaction<RequestOutcome>(
      async (tx) => {
        await this.lockPair(tx, senderId, receiverId);
        await this.ensureNotBlocked(senderId, receiverId, tx);

        const existingFriendship = await tx.friendRequest.findFirst({
          where: {
            status: FriendRequestStatus.ACCEPTED,
            OR: [
              { senderId, receiverId },
              { senderId: receiverId, receiverId: senderId },
            ],
          },
        });

        if (existingFriendship) {
          await this.cancelOtherPendingRequests(
            tx,
            existingFriendship.id,
            senderId,
            receiverId,
          );
          return {
            status: 'FRIENDS',
            message: 'You are already friends.',
            request: existingFriendship,
            sideEffects: emptySideEffects(),
          };
        }

        // If the other user already requested me, accept that request
        // instead of creating a duplicate request in the opposite direction.
        const reverseRequest = await tx.friendRequest.findFirst({
          where: {
            senderId: receiverId,
            receiverId: senderId,
            status: FriendRequestStatus.PENDING,
          },
        });

        if (reverseRequest) {
          const accepted = await tx.friendRequest.update({
            where: { id: reverseRequest.id },
            data: { status: FriendRequestStatus.ACCEPTED },
          });

          await this.cancelOtherPendingRequests(
            tx,
            accepted.id,
            senderId,
            receiverId,
          );
          await this.resolveFriendRequestNotification(
            tx,
            reverseRequest.id,
            'FRIEND_REQUEST_ACCEPTED',
            reverseRequest.senderId,
          );

          const [senderNotification, receiverNotification] = await Promise.all([
            this.persistNotification(
              tx,
              senderId,
              'Friendship created',
              `You and ${receiverName} are now friends.`,
              { kind: 'FRIENDSHIP_CREATED', friendId: receiverId },
            ),
            this.persistNotification(
              tx,
              receiverId,
              'Friendship created',
              `You and ${senderName} are now friends.`,
              { kind: 'FRIENDSHIP_CREATED', friendId: senderId },
            ),
          ]);

          return {
            status: 'FRIENDS',
            message: 'Friend request accepted. You are now friends.',
            request: accepted,
            sideEffects: {
              notifications: [
                { userId: senderId, notification: senderNotification },
                { userId: receiverId, notification: receiverNotification },
              ],
              events: [
                {
                  userId: senderId,
                  event: 'FRIENDSHIP_CREATED',
                  payload: { friendId: receiverId },
                },
                {
                  userId: receiverId,
                  event: 'FRIENDSHIP_CREATED',
                  payload: { friendId: senderId },
                },
              ],
            },
          };
        }

        const existingPending = await tx.friendRequest.findFirst({
          where: {
            senderId,
            receiverId,
            status: FriendRequestStatus.PENDING,
          },
        });

        if (existingPending) {
          return {
            status: 'PENDING',
            message: 'Friend request is already pending.',
            request: existingPending,
            sideEffects: emptySideEffects(),
          };
        }

        const request = await tx.friendRequest.create({
          data: { senderId, receiverId },
        });

        const notification = await this.persistNotification(
          tx,
          receiverId,
          'Friend request',
          `${senderName} wants to add you as a friend.`,
          {
            kind: 'FRIEND_REQUEST',
            requestId: request.id,
            senderId,
            senderName,
          },
        );

        return {
          status: 'PENDING',
          message: 'Friend request sent.',
          request,
          sideEffects: {
            notifications: [{ userId: receiverId, notification }],
            events: [
              {
                userId: receiverId,
                event: 'FRIEND_REQUEST_RECEIVED',
                payload: {
                  requestId: request.id,
                  senderId,
                  notificationId: notification.id,
                },
              },
            ],
          },
        };
      },
    );

    await this.dispatchSideEffects(outcome.sideEffects);

    return {
      status: outcome.status,
      message: outcome.message,
      request: outcome.request,
    };
  }

  async receivedRequests(userId: string) {
    return this.prisma.friendRequest.findMany({
      where: {
        receiverId: userId,
        status: FriendRequestStatus.PENDING,
      },
      include: {
        sender: {
          select: {
            id: true,
            profile: { select: { name: true, avatar: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async sentRequests(userId: string) {
    return this.prisma.friendRequest.findMany({
      where: {
        senderId: userId,
        status: FriendRequestStatus.PENDING,
      },
      include: {
        receiver: {
          select: {
            id: true,
            profile: { select: { name: true, avatar: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async acceptRequest(userId: string, requestId: string) {
    const outcome = await this.prisma.$transaction<RequestOutcome>(
      async (tx) => {
        const initial = await tx.friendRequest.findUnique({
          where: { id: requestId },
        });

        if (!initial) {
          throw new NotFoundException('Friend request not found.');
        }

        if (initial.receiverId !== userId) {
          throw new ForbiddenException(
            'You cannot accept another user’s friend request.',
          );
        }

        await this.lockPair(tx, initial.senderId, initial.receiverId);

        const request = await tx.friendRequest.findUnique({
          where: { id: requestId },
          include: {
            sender: {
              select: { id: true, profile: { select: { name: true } } },
            },
            receiver: {
              select: { id: true, profile: { select: { name: true } } },
            },
          },
        });

        if (!request) {
          throw new NotFoundException('Friend request not found.');
        }

        if (request.receiverId !== userId) {
          throw new ForbiddenException(
            'You cannot accept another user’s friend request.',
          );
        }

        if (request.status === FriendRequestStatus.ACCEPTED) {
          await this.resolveFriendRequestNotification(
            tx,
            request.id,
            'FRIEND_REQUEST_ACCEPTED',
            request.senderId,
          );
          return {
            status: 'FRIENDS',
            message: 'You are already friends.',
            request,
            sideEffects: emptySideEffects(),
          };
        }

        if (request.status !== FriendRequestStatus.PENDING) {
          throw new BadRequestException('This request is no longer pending.');
        }

        await this.ensureNotBlocked(
          request.senderId,
          request.receiverId,
          tx,
        );

        const existingFriendship = await tx.friendRequest.findFirst({
          where: {
            id: { not: request.id },
            status: FriendRequestStatus.ACCEPTED,
            OR: [
              {
                senderId: request.senderId,
                receiverId: request.receiverId,
              },
              {
                senderId: request.receiverId,
                receiverId: request.senderId,
              },
            ],
          },
        });

        if (existingFriendship) {
          // A mutual request already produced the friendship. Keep exactly
          // one accepted row; resolve this redundant pending request.
          await tx.friendRequest.update({
            where: { id: request.id },
            data: { status: FriendRequestStatus.CANCELLED },
          });
          await this.resolveFriendRequestNotification(
            tx,
            request.id,
            'FRIEND_REQUEST_ACCEPTED',
            request.senderId,
          );
          return {
            status: 'FRIENDS',
            message: 'You are already friends.',
            request: existingFriendship,
            sideEffects: emptySideEffects(),
          };
        }

        const accepted = await tx.friendRequest.update({
          where: { id: request.id },
          data: { status: FriendRequestStatus.ACCEPTED },
        });

        await this.cancelOtherPendingRequests(
          tx,
          accepted.id,
          request.senderId,
          request.receiverId,
        );
        await this.resolveFriendRequestNotification(
          tx,
          request.id,
          'FRIEND_REQUEST_ACCEPTED',
          request.senderId,
        );

        const senderName = request.sender.profile?.name ?? 'Someone';
        const receiverName = request.receiver.profile?.name ?? 'Someone';

        const [senderNotification, receiverNotification] = await Promise.all([
          this.persistNotification(
            tx,
            request.senderId,
            'Friend request accepted',
            `${receiverName} accepted your friend request.`,
            {
              kind: 'FRIEND_REQUEST_ACCEPTED',
              requestId: request.id,
              friendId: userId,
            },
          ),
          this.persistNotification(
            tx,
            userId,
            'Friendship created',
            `You and ${senderName} are now friends.`,
            {
              kind: 'FRIENDSHIP_CREATED',
              friendId: request.senderId,
            },
          ),
        ]);

        return {
          status: 'FRIENDS',
          message: 'Friend request accepted.',
          request: accepted,
          sideEffects: {
            notifications: [
              {
                userId: request.senderId,
                notification: senderNotification,
              },
              { userId, notification: receiverNotification },
            ],
            events: [
              {
                userId: request.senderId,
                event: 'FRIEND_REQUEST_ACCEPTED',
                payload: { friendId: userId, requestId: request.id },
              },
              {
                userId,
                event: 'FRIENDSHIP_CREATED',
                payload: { friendId: request.senderId },
              },
            ],
          },
        };
      },
    );

    await this.dispatchSideEffects(outcome.sideEffects);

    return {
      status: outcome.status,
      message: outcome.message,
      request: outcome.request,
    };
  }

  async declineRequest(userId: string, requestId: string) {
    return this.prisma.$transaction(async (tx) => {
      const initial = await tx.friendRequest.findUnique({
        where: { id: requestId },
      });

      if (!initial) {
        throw new NotFoundException('Friend request not found.');
      }

      if (initial.receiverId !== userId) {
        throw new ForbiddenException('You cannot decline this request.');
      }

      await this.lockPair(tx, initial.senderId, initial.receiverId);

      const request = await tx.friendRequest.findUnique({
        where: { id: requestId },
      });

      if (!request) {
        throw new NotFoundException('Friend request not found.');
      }

      if (request.status !== FriendRequestStatus.PENDING) {
        throw new BadRequestException('This request is no longer pending.');
      }

      const updated = await tx.friendRequest.update({
        where: { id: requestId },
        data: { status: FriendRequestStatus.DECLINED },
      });

      await this.resolveFriendRequestNotification(
        tx,
        request.id,
        'FRIEND_REQUEST_DECLINED',
        request.senderId,
      );

      return updated;
    });
  }

  async cancelRequest(userId: string, requestId: string) {
    return this.prisma.$transaction(async (tx) => {
      const initial = await tx.friendRequest.findUnique({
        where: { id: requestId },
      });

      if (!initial) {
        throw new NotFoundException('Friend request not found.');
      }

      if (initial.senderId !== userId) {
        throw new ForbiddenException('You cannot cancel this request.');
      }

      await this.lockPair(tx, initial.senderId, initial.receiverId);

      const request = await tx.friendRequest.findUnique({
        where: { id: requestId },
      });

      if (!request) {
        throw new NotFoundException('Friend request not found.');
      }

      if (request.status !== FriendRequestStatus.PENDING) {
        throw new BadRequestException('This request is no longer pending.');
      }

      const updated = await tx.friendRequest.update({
        where: { id: requestId },
        data: { status: FriendRequestStatus.CANCELLED },
      });

      await this.resolveFriendRequestNotification(
        tx,
        request.id,
        'FRIEND_REQUEST_CANCELLED',
        request.senderId,
      );

      return updated;
    });
  }

  async listFriends(userId: string) {
    const requests = await this.prisma.friendRequest.findMany({
      where: {
        status: FriendRequestStatus.ACCEPTED,
        OR: [{ senderId: userId }, { receiverId: userId }],
      },
      include: {
        sender: {
          include: {
            profile: true,
          },
        },
        receiver: {
          include: {
            profile: true,
          },
        },
      },
      orderBy: {
        updatedAt: 'desc',
      },
    });

    const seen = new Set<string>();
    const friends: {
      userId: string;
      name: string | null;
      avatar: string | null;
      friendSince: Date;
      online: boolean;
    }[] = [];

    for (const request of requests) {
      const friend =
        request.senderId === userId ? request.receiver : request.sender;

      if (!friend || seen.has(friend.id)) continue;
      seen.add(friend.id);

      friends.push({
        userId: friend.id,
        name: friend.profile?.name ?? null,
        avatar: friend.profile?.avatar ?? null,
        friendSince: request.updatedAt,
          online: await this.presence.isOnline(friend.id),
      });
    }

    return friends;
  }
}
