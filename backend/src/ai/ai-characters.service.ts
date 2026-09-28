// import { Injectable } from '@nestjs/common';
// import { PrismaService } from '../prisma/prisma.service';
// import { notFound } from '../common/errors/api.exception';

// @Injectable()
// export class AICharactersService {
//   constructor(private readonly prisma: PrismaService) { }

//   async list(includePremium: boolean) {
//     return this.prisma.aICharacter.findMany({
//       where: includePremium ? {} : { isActive: true, isPremium: false },
//       orderBy: [{ isPremium: 'asc' }, { name: 'asc' }],
//       select: {
//         id: true,
//         name: true,
//         description: true,
//         avatar: true,
//         difficulty: true,
//         scenario: true,
//         isPremium: true,
//         isActive: true,
//       },
//     });
//   }

//   async getActive(id: string) {
//     const character = await this.prisma.aICharacter.findFirst({
//       where: { id, isActive: true },
//       include: { sessions: false },
//     });
//     if (!character) throw notFound('CHARACTER_NOT_FOUND', 'AI character not found');
//     return character;
//   }



//   async scenarios(): Promise<string[]> {
//     return [
//       'daily',
//       'interview',
//       'travel',
//       'business',
//       'technology',
//       'education',
//       'shopping',
//       'restaurant',
//       'smalltalk',
//       'publicspeaking',
//     ];
//   }
// }

import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

import { notFound } from '../common/errors/api.exception';

@Injectable()
export class AICharactersService {
  constructor(private readonly prisma: PrismaService) {}

  // Return ALL AI characters
  async list() {
    return this.prisma.aICharacter.findMany({
      orderBy: [
        { isPremium: 'asc' },
        { name: 'asc' },
      ],

      select: {
        id: true,
        name: true,
        description: true,
        avatar: true,
        difficulty: true,
        scenario: true,
        isPremium: true,
        isActive: true,
      },
    });
  }

  async getActive(id: string) {
    const character = await this.prisma.aICharacter.findFirst({
      where: {
        id,
        isActive: true,
      },
      include: {
        sessions: false,
      },
    });

    if (!character) {
      throw notFound(
        'CHARACTER_NOT_FOUND',
        'AI character not found',
      );
    }

    return character;
  }

  async scenarios(): Promise<string[]> {
    return [
      'daily',
      'interview',
      'travel',
      'business',
      'technology',
      'education',
      'shopping',
      'restaurant',
      'smalltalk',
      'publicspeaking',
    ];
  }
}