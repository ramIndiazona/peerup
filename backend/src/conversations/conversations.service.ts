
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeEventsService } from '../realtime/realtime-events.service';

@Injectable()
export class ConversationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtimeEvents: RealtimeEventsService,
  ) {}

  /**
   * Normalize IDs so user A and user B always use
   * the same conversation record.
   */
  private normalizeUsers(userId: string, friendId: string) {
    if (userId === friendId) {
      throw new BadRequestException(
        'You cannot create a conversation with yourself.',
      );
    }

    return [userId, friendId].sort();
  }

  /**
   * Check whether two users are friends and neither
   * user has blocked the other.
   */
  private async ensureCanChat(userId: string, friendId: string) {
    const [users, block, friendship] = await Promise.all([
      this.prisma.user.findMany({
        where: { id: { in: [userId, friendId] } },
        select: { id: true },
      }),

      this.prisma.block.findFirst({
        where: {
          OR: [
            { blockerId: userId, blockedId: friendId },
            { blockerId: friendId, blockedId: userId },
          ],
        },
        select: { id: true },
      }),

      this.prisma.friendRequest.findFirst({
        where: {
          status: 'ACCEPTED',
          OR: [
            { senderId: userId, receiverId: friendId },
            { senderId: friendId, receiverId: userId },
          ],
        },
        select: { id: true },
      }),
    ]);

    if (users.length !== 2) {
      throw new NotFoundException('User not found.');
    }

    if (block) {
      throw new ForbiddenException(
        'You cannot chat with this user.',
      );
    }

    if (!friendship) {
      throw new ForbiddenException(
        'You can chat only with accepted friends.',
      );
    }
  }

  /**
   * Create a conversation or return the existing one.
   */
  async createConversation(userId: string, friendId: string) {
    await this.ensureCanChat(userId, friendId);

    const [userAId, userBId] = this.normalizeUsers(
      userId,
      friendId,
    );

    return this.prisma.conversation.upsert({
      where: {
        userAId_userBId: {
          userAId,
          userBId,
        },
      },
      create: {
        userAId,
        userBId,
      },
      update: {},
      include: {
        userA: {
          select: {
            id: true,
            profile: {
              select: {
                name: true,
                avatar: true,
              },
            },
          },
        },
        userB: {
          select: {
            id: true,
            profile: {
              select: {
                name: true,
                avatar: true,
              },
            },
          },
        },
      },
    });
  }

  /**
   * List conversations for the logged-in user.
   */
  async listConversations(userId: string) {
    const conversations = await this.prisma.conversation.findMany({
      where: {
        OR: [
          { userAId: userId },
          { userBId: userId },
        ],
      },
      include: {
        userA: {
          select: {
            id: true,
            profile: {
              select: {
                name: true,
                avatar: true,
              },
            },
          },
        },
        userB: {
          select: {
            id: true,
            profile: {
              select: {
                name: true,
                avatar: true,
              },
            },
          },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: {
            id: true,
            senderId: true,
            content: true,
            messageType: true,
            createdAt: true,
          },
        },
      },
      orderBy: [
        { lastMessageAt: 'desc' },
        { updatedAt: 'desc' },
      ],
    });

    return conversations.map((conversation) => {
      const friend =
        conversation.userAId === userId
          ? conversation.userB
          : conversation.userA;

      return {
        id: conversation.id,
        friend: {
          id: friend.id,
          name: friend.profile?.name ?? null,
          avatar: friend.profile?.avatar ?? null,
        },
        lastMessage: conversation.messages[0] ?? null,
        lastMessageAt: conversation.lastMessageAt,
        updatedAt: conversation.updatedAt,
      };
    });
  }

  /**
   * Save a message and deliver it to the recipient in real time.
   */
  async sendMessage(
    userId: string,
    conversationId: string,
    content: string,
  ) {
    const trimmedContent = content.trim();

    if (!trimmedContent) {
      throw new BadRequestException(
        'Message content cannot be empty.',
      );
    }

    if (trimmedContent.length > 5000) {
      throw new BadRequestException(
        'Message cannot exceed 5000 characters.',
      );
    }

    const conversation =
      await this.prisma.conversation.findUnique({
        where: { id: conversationId },
        select: {
          id: true,
          userAId: true,
          userBId: true,
        },
      });

    if (!conversation) {
      throw new NotFoundException('Conversation not found.');
    }

    if (
      conversation.userAId !== userId &&
      conversation.userBId !== userId
    ) {
      throw new ForbiddenException(
        'You do not have access to this conversation.',
      );
    }

    const friendId =
      conversation.userAId === userId
        ? conversation.userBId
        : conversation.userAId;

    // Recheck friendship and blocks for every message.
    await this.ensureCanChat(userId, friendId);

    const message = await this.prisma.$transaction(
      async (tx) => {
        const savedMessage = await tx.message.create({
          data: {
            conversationId,
            senderId: userId,
            content: trimmedContent,
            messageType: 'TEXT',
          },
          select: {
            id: true,
            conversationId: true,
            senderId: true,
            content: true,
            messageType: true,
            createdAt: true,
            readAt: true,
          },
        });

        await tx.conversation.update({
          where: { id: conversationId },
          data: { lastMessageAt: savedMessage.createdAt },
        });

        return savedMessage;
      },
    );

    // The database save succeeds independently of whether
    // the recipient currently has an active socket.
    this.realtimeEvents.sendToUser(
      friendId,
      'CHAT_MESSAGE',
      message,
    );

    this.realtimeEvents.sendToUser(
      userId,
      'CHAT_MESSAGE',
      message,
    );

    return message;
  }

  /**
   * Retrieve persisted message history.
   */
  async getMessages(
    userId: string,
    conversationId: string,
    limit = 50,
    before?: string,
  ) {
    const conversation =
      await this.prisma.conversation.findUnique({
        where: { id: conversationId },
        select: {
          id: true,
          userAId: true,
          userBId: true,
        },
      });

    if (!conversation) {
      throw new NotFoundException('Conversation not found.');
    }

    if (
      conversation.userAId !== userId &&
      conversation.userBId !== userId
    ) {
      throw new ForbiddenException(
        'You do not have access to this conversation.',
      );
    }

    const friendId =
      conversation.userAId === userId
        ? conversation.userBId
        : conversation.userAId;

    await this.ensureCanChat(userId, friendId);

    const safeLimit = Math.min(
      Math.max(Number(limit) || 50, 1),
      100,
    );

    const beforeDate = before ? new Date(before) : undefined;

    if (before && Number.isNaN(beforeDate!.getTime())) {
      throw new BadRequestException(
        'Invalid message cursor date.',
      );
    }

    const messages = await this.prisma.message.findMany({
      where: {
        conversationId,
        ...(beforeDate
          ? { createdAt: { lt: beforeDate } }
          : {}),
      },
      orderBy: [
        { createdAt: 'desc' },
        { id: 'desc' },
      ],
      take: safeLimit,
      select: {
        id: true,
        conversationId: true,
        senderId: true,
        content: true,
        messageType: true,
        createdAt: true,
        readAt: true,
      },
    });

    // Return oldest-to-newest for easier chat rendering.
    return messages.reverse();
  }
}
