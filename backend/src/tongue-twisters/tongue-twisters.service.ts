import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTongueTwisterDto } from './dto/create-tongue-twister.dto';

@Injectable()
export class TongueTwistersService {
  constructor(private readonly prisma: PrismaService) { }

  async findAll() {
    return this.prisma.tongueTwister.findMany({
      where: { isActive: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const tongueTwister =
      await this.prisma.tongueTwister.findFirst({
        where: {
          id,
          isActive: true,
        },
      });

    if (!tongueTwister) {
      throw new NotFoundException('Tongue twister not found');
    }

    return tongueTwister;
  }

  async create(dto: CreateTongueTwisterDto) {
    return this.prisma.tongueTwister.create({
      data: {
        title: dto.title,
        text: dto.text,
        level: dto.level ?? 'beginner',
        seconds: dto.seconds ?? 60,
        xp: dto.xp ?? 10,
        color: dto.color ?? '#625FE8',
        icon: dto.icon ?? 'record_voice_over',
      },
    });
  }

  async createMany(items: CreateTongueTwisterDto[]) {
    return this.prisma.$transaction(
      items.map((item) =>
        this.prisma.tongueTwister.create({
          data: {
            title: item.title,
            text: item.text,
            level: item.level,
            seconds: item.seconds,
            xp: item.xp,
            color: item.color,
            icon: item.icon,
          },
        }),
      ),
    );
  }

}