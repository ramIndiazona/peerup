import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  FriendRequestStatus,
  NotificationType,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeEventsService } from '../realtime/realtime-events.service';

@Injectable()
export class FriendRequestsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: RealtimeEventsService,
  ) {}

  private async ensureNotBlocked(
    userAId: string,
    userBId: string,
  ): Promise<void> {
    const block = await this.prisma.block.findFirst({
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

  private async createInAppNotification(
    userId: string,
    title: string,
    body: string,
    data: Record<string, unknown>,
  ) {
    // Save in-app notification only. Do not send an FCM push alert.
    const notification = await this.prisma.notification.create({
      data: {
        userId,
        type: NotificationType.SYSTEM,
        title,
        body,
        data: data as Prisma.InputJsonValue,
      },
    });

    await this.events.sendToUser(userId, 'NOTIFICATION_CREATED', {
      notification,
    });

    return notification;
  }

  async sendRequest(senderId: string, receiverId: string) {
    if (senderId === receiverId) {
      throw new BadRequestException(
        'You cannot send a friend request to yourself.',
      );
    }

    const receiver = await this.prisma.user.findUnique({
      where: { id: receiverId },
      select: { id: true, profile: { select: { name: true } } },
    });

    if (!receiver) {
      throw new NotFoundException('User not found.');
    }

    await this.ensureNotBlocked(senderId, receiverId);

    const existingFriendship = await this.prisma.friendRequest.findFirst({
      where: {
        status: FriendRequestStatus.ACCEPTED,
        OR: [
          { senderId, receiverId },
          { senderId: receiverId, receiverId: senderId },
        ],
      },
    });

    if (existingFriendship) {
      return { status: 'FRIENDS', request: existingFriendship };
    }

    // If the other user already requested me, accept that request
    // instead of creating a duplicate request in the opposite direction.
    const reverseRequest = await this.prisma.friendRequest.findFirst({
      where: {
        senderId: receiverId,
        receiverId: senderId,
        status: FriendRequestStatus.PENDING,
      },
    });

    if (reverseRequest) {
      const accepted = await this.prisma.friendRequest.update({
        where: { id: reverseRequest.id },
        data: { status: FriendRequestStatus.ACCEPTED },
      });

      await Promise.all([
        this.createInAppNotification(
          senderId,
          'Friendship created',
          'You are now friends.',
          { kind: 'FRIENDSHIP_CREATED', friendId: receiverId },
        ),
        this.createInAppNotification(
          receiverId,
          'Friendship created',
          'You are now friends.',
          { kind: 'FRIENDSHIP_CREATED', friendId: senderId },
        ),
        this.events.sendToUser(senderId, 'FRIENDSHIP_CREATED', {
          friendId: receiverId,
        }),
        this.events.sendToUser(receiverId, 'FRIENDSHIP_CREATED', {
          friendId: senderId,
        }),
      ]);

      return { status: 'FRIENDS', request: accepted };
    }

    const existingPending = await this.prisma.friendRequest.findFirst({
      where: {
        senderId,
        receiverId,
        status: FriendRequestStatus.PENDING,
      },
    });

    if (existingPending) {
      return { status: 'PENDING', request: existingPending };
    }

    const request = await this.prisma.friendRequest.create({
      data: { senderId, receiverId },
    });

    const notification = await this.createInAppNotification(
      receiverId,
      'Friend request',
      'Someone wants to add you as a friend.',
      { kind: 'FRIEND_REQUEST', requestId: request.id, senderId },
    );

    await this.events.sendToUser(receiverId, 'FRIEND_REQUEST_RECEIVED', {
      requestId: request.id,
      senderId,
      notificationId: notification.id,
    });

    return { status: 'PENDING', request };
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
    const request = await this.prisma.friendRequest.findUnique({
      where: { id: requestId },
    });

    if (!request) {
      throw new NotFoundException('Friend request not found.');
    }

    if (request.receiverId !== userId) {
      throw new ForbiddenException(
        'You cannot accept another user’s friend request.',
      );
    }

    if (request.status !== FriendRequestStatus.PENDING) {
      throw new BadRequestException('This request is no longer pending.');
    }

    await this.ensureNotBlocked(request.senderId, request.receiverId);

    const accepted = await this.prisma.friendRequest.update({
      where: { id: requestId },
      data: { status: FriendRequestStatus.ACCEPTED },
    });

    await Promise.all([
      this.createInAppNotification(
        request.senderId,
        'Friend request accepted',
        'Your friend request was accepted.',
        { kind: 'FRIEND_REQUEST_ACCEPTED', friendId: userId },
      ),
      this.events.sendToUser(request.senderId, 'FRIEND_REQUEST_ACCEPTED', {
        friendId: userId,
        requestId,
      }),
      this.events.sendToUser(userId, 'FRIENDSHIP_CREATED', {
        friendId: request.senderId,
      }),
    ]);

    return { status: 'FRIENDS', request: accepted };
  }

  async declineRequest(userId: string, requestId: string) {
    const request = await this.prisma.friendRequest.findUnique({
      where: { id: requestId },
    });

    if (!request) {
      throw new NotFoundException('Friend request not found.');
    }

    if (request.receiverId !== userId) {
      throw new ForbiddenException('You cannot decline this request.');
    }

    if (request.status !== FriendRequestStatus.PENDING) {
      throw new BadRequestException('This request is no longer pending.');
    }

    return this.prisma.friendRequest.update({
      where: { id: requestId },
      data: { status: FriendRequestStatus.DECLINED },
    });
  }

  async cancelRequest(userId: string, requestId: string) {
    const request = await this.prisma.friendRequest.findUnique({
      where: { id: requestId },
    });

    if (!request) {
      throw new NotFoundException('Friend request not found.');
    }

    if (request.senderId !== userId) {
      throw new ForbiddenException('You cannot cancel this request.');
    }

    if (request.status !== FriendRequestStatus.PENDING) {
      throw new BadRequestException('This request is no longer pending.');
    }

    return this.prisma.friendRequest.update({
      where: { id: requestId },
      data: { status: FriendRequestStatus.CANCELLED },
    });
  }


async listFriends(userId: string) {
  const requests = await this.prisma.friendRequest.findMany({
    where: {
      status: 'ACCEPTED',
      OR: [
        { senderId: userId },
        { receiverId: userId },
      ],
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

  return requests.map((request) => {
    const friend =
      request.senderId === userId
        ? request.receiver
        : request.sender;

    return {
      userId: friend.id,
      name: friend.profile?.name ?? null,
      avatar: friend.profile?.avatar ?? null,
      friendSince: request.updatedAt,
    };
  });
}

}