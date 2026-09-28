import { Injectable } from '@nestjs/common';
import { Gender, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ApiException, forbidden, notFound } from '../common/errors/api.exception';
import { UpdateProfileDto } from './dto/profile.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) { }

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        profile: {
          include: {
            userInterests: { include: { interest: true } },
          },
        },
        subscriptions: true,
      },
    });
    if (!user) throw notFound('USER_NOT_FOUND', 'User not found');
    return this.toPrivateView(user);
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const { interests, ...profileFields } = dto;

    const existing = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, profile: { select: { id: true } } },
    });
    if (!existing) throw notFound('USER_NOT_FOUND', 'User not found');
    if (!existing.profile) {
      throw new ApiException('PROFILE_NOT_READY', 'Profile not initialized', 400);
    }

    if (dto.dateOfBirth) {
      // guard absurd birthdays
      const dob = new Date(dto.dateOfBirth);
      const age = this.ageFrom(dob);
      if (age < 16) {
        throw forbidden('AGE_REQUIREMENT', 'You must be at least 16 years old');
      }
    }

    const result = await this.prisma.$transaction(async (tx) => {
      let interestIds: string[] = [];
      if (interests) {
        interestIds = await this.upsertInterests(tx, interests);
        await tx.userInterest.deleteMany({ where: { userId } });

        if (interestIds.length > 0) {
          await tx.userInterest.createMany({
            data: interestIds.map((interestId) => ({
              userId,
              profileId: existing.profile!.id,
              interestId,
            })),
          });
        }
      }

      const profile = await tx.profile.update({
        where: { userId },
        data: {
          ...(profileFields.name !== undefined ? { name: profileFields.name } : {}),
          ...(profileFields.avatar !== undefined ? { avatar: profileFields.avatar } : {}),
          ...(profileFields.gender !== undefined ? { gender: profileFields.gender } : {}),
          ...(profileFields.dateOfBirth !== undefined
            ? { dateOfBirth: new Date(profileFields.dateOfBirth) }
            : {}),
          ...(profileFields.country !== undefined ? { country: profileFields.country } : {}),
          ...(profileFields.nativeLanguage !== undefined
            ? { nativeLanguage: profileFields.nativeLanguage }
            : {}),
          ...(profileFields.learningLanguage !== undefined
            ? { learningLanguage: profileFields.learningLanguage }
            : {}),
          ...(profileFields.englishLevel !== undefined
            ? { englishLevel: profileFields.englishLevel }
            : {}),
          ...(profileFields.bio !== undefined ? { bio: profileFields.bio } : {}),
          ...(profileFields.conversationGoals !== undefined
            ? { conversationGoals: profileFields.conversationGoals }
            : {}),
          ...(profileFields.showAge !== undefined ? { showAge: profileFields.showAge } : {}),
          ...(profileFields.showGender !== undefined
            ? { showGender: profileFields.showGender }
            : {}),
          ...(profileFields.onboardingCompleted !== undefined
            ? { onboardingCompleted: profileFields.onboardingCompleted }
            : {}),
        },
        include: {
          userInterests: { include: { interest: true } },
        },
      });

      return tx.user.findUniqueOrThrow({
        where: { id: userId },
        include: {
          profile: { include: { userInterests: { include: { interest: true } } } },
        },
      });
    });

    return this.toPrivateView(result);
  }

  async getPublicProfile(viewer: string, userId: string) {
    if (viewer === userId) return this.getMe(userId);

    const blocked = await this.isBlocked(viewer, userId);
    if (blocked) {
      throw forbidden('BLOCKED', 'This profile is unavailable');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        profile: {
          include: { userInterests: { include: { interest: true } } },
        },
      },
    });
    if (!user || user.isBanned) {
      throw notFound('USER_NOT_FOUND', 'User not found');
    }

    return this.toPublicView(user, viewer, userId);
  }

  async listAvailableInterests() {
    return this.prisma.interest.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' },
    });
  }

  // ---------------- helpers ----------------

  private async upsertInterests(
    tx: Prisma.TransactionClient,
    names: string[],
  ): Promise<string[]> {
    const normalized = [...new Set(names.map((n) => n.trim().toLowerCase()))].filter(Boolean);
    const ids: string[] = [];
    for (const name of normalized) {
      const interest = await tx.interest.upsert({
        where: { name },
        update: {},
        create: { name },
        select: { id: true },
      });
      ids.push(interest.id);
    }
    return ids;
  }

  private ageFrom(dob: Date): number {
    const now = new Date();
    let age = now.getFullYear() - dob.getFullYear();
    const m = now.getMonth() - dob.getMonth();
    if (m < 0 || (m === 0 && now.getDate() < dob.getDate())) age--;
    return age;
  }

  private async isBlocked(blockerId: string, blockedId: string): Promise<boolean> {
    return (await this.prisma.block.count({ where: { blockerId, blockedId } })) > 0;
  }

  private toPrivateView(user: any) {
    const p = user.profile ?? { name: user.email, gender: Gender.PREFER_NOT_TO_SAY };
    return {
      id: user.id,
      email: user.email,
      phone: user.phone,
      role: user.role,
      status: user.status,
      isBanned: user.isBanned,
      createdAt: user.createdAt,
      profile: {
        id: p.id,
        name: p.name,
        avatar: p.avatar,
        gender: p.gender,
        dateOfBirth: p.dateOfBirth,
        country: p.country,
        nativeLanguage: p.nativeLanguage,
        learningLanguage: p.learningLanguage,
        englishLevel: p.englishLevel,
        bio: p.bio,
        conversationGoals: p.conversationGoals ?? [],
        interests: (p.userInterests ?? []).map((ui: any) => ui.interest.name),
        showAge: p.showAge,
        showGender: p.showGender,
        onboardingCompleted: p.onboardingCompleted,
      },
      subscription: (user.subscriptions?.[0] ?? { plan: 'FREE' }).plan,
    };
  }

  private toPublicView(user: any, viewer: string, target: string) {
    const p = user.profile;
    const yearsOld =
      p.dateOfBirth && (p.showAge || viewer === target)
        ? this.ageFrom(new Date(p.dateOfBirth))
        : null;
    return {
      id: user.id,
      name: p.name,
      avatar: p.avatar,
      englishLevel: p.englishLevel,
      nativeLanguage: p.nativeLanguage,
      country: p.country,
      bio: p.bio,
      gender: p.showGender ? p.gender : undefined,
      yearsOld,
      interests: (p.userInterests ?? []).map((ui: any) => ui.interest.name),
      conversationGoals: p.conversationGoals ?? [],
    };
  }
}