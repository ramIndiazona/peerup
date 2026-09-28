// // import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
// // import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
// // import { IsIn, IsOptional, IsString } from 'class-validator';
// // import { EnglishLevel } from '@prisma/client';
// // import { CurrentUser } from '../common/decorators/current-user.decorator';
// // import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
// // import { MatchmakingService } from './matchmaking.service';

// // class StartMatchDto {
// //   @IsOptional()
// //   @IsString()
// //   language?: string;

// //   @IsOptional()
// //   @IsString()
// //   level?: string;

// //   @IsOptional()
// //   @IsString()
// //   preferredLevel?: string; // "A2-C1"

// //   @IsOptional()
// //   interests?: string[];

// //   @IsOptional()
// //   @IsString()
// //   genderPreference?: 'MALE' | 'FEMALE' | 'any';

// //   @IsOptional()
// //   @IsString()
// //   goal?: string;

// //   @IsOptional()
// //   @IsString()
// //   matchType?: string;
// // }

// // class CancelMatchDto {}

// // @ApiTags('matchmaking')
// // @ApiBearerAuth()
// // @UseGuards(JwtAuthGuard)
// // @Controller('matchmaking')
// // export class MatchmakingController {
// //   constructor(private readonly matchmaking: MatchmakingService) {}

// //   @Post('start')
// //   @HttpCode(200)
// //   @ApiOperation({ summary: 'Begin searching for a live conversation partner' })
// //   start(@CurrentUser('id') userId: string, @Body() dto: StartMatchDto) {
// //     return this.matchmaking.start(userId, {
// //       language: dto.language,
// //       level: dto.level,
// //       preferredLevel: this.parsePreferredLevel(dto.preferredLevel),
// //       interests: dto.interests,
// //       genderPreference: dto.genderPreference as any,
// //       goal: dto.goal,
// //       matchType: dto.matchType,
// //     });
// //   }

// //   @Post('cancel')
// //   @HttpCode(200)
// //   @ApiOperation({ summary: 'Cancel an active search' })
// //   cancel(@CurrentUser('id') userId: string) {
// //     return this.matchmaking.cancel(userId);
// //   }

// //   @Post('status')
// //   @HttpCode(200)
// //   @ApiOperation({ summary: 'Get current matchmaking status' })
// //   status(@CurrentUser('id') userId: string) {
// //     return this.matchmaking.getStatus(userId);
// //   }

// //   private parsePreferredLevel(input?: string): { min?: string; max?: string } | undefined {
// //     if (!input) return undefined;
// //     const parts = input.split('-').map((s) => s.trim().toUpperCase());
// //     if (parts.length !== 2) return undefined;
// //     return { min: parts[0], max: parts[1] };
// //   }
// // }

// import {
//   Body,
//   Controller,
//   HttpCode,
//   Post,
//   UseGuards,
// } from '@nestjs/common';

// import {
//   ApiBearerAuth,
//   ApiOperation,
//   ApiTags,
// } from '@nestjs/swagger';

// import {
//   IsArray,
//   IsIn,
//   IsOptional,
//   IsString,
// } from 'class-validator';

// import { CurrentUser } from '../common/decorators/current-user.decorator';
// import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
// import { MatchmakingService } from './matchmaking.service';

// class StartMatchDto {
//   @IsOptional()
//   @IsString()
//   language?: string;

//   @IsOptional()
//   @IsString()
//   level?: string;

//   /**
//    * Example:
//    * "A2-C1"
//    */
//   @IsOptional()
//   @IsString()
//   preferredLevel?: string;

//   @IsOptional()
//   @IsArray()
//   @IsString({ each: true })
//   interests?: string[];

//   @IsOptional()
//   @IsIn(['MALE', 'FEMALE', 'any'])
//   genderPreference?: 'MALE' | 'FEMALE' | 'any';

//   @IsOptional()
//   @IsString()
//   goal?: string;

//   @IsOptional()
//   @IsIn([
//     'random',
//     'level',
//     'interview',
//     'business',
//     'casual',
//   ])
//   matchType?: string;
// }

// @ApiTags('matchmaking')
// @ApiBearerAuth()
// @UseGuards(JwtAuthGuard)
// @Controller('matchmaking')
// export class MatchmakingController {
//   constructor(
//     private readonly matchmaking: MatchmakingService,
//   ) {}

//   @Post('start')
//   @HttpCode(200)
//   @ApiOperation({
//     summary: 'Start searching for a conversation partner',
//   })
//   async start(
//     @CurrentUser('id') userId: string,
//     @Body() dto: StartMatchDto,
//   ) {
//     const preferredLevel = this.parsePreferredLevel(
//       dto.preferredLevel,
//     );

//     return this.matchmaking.start(userId, {
//       language: dto.language?.trim(),
//       level: dto.level?.trim().toUpperCase(),

//       preferredLevel,

//       interests: dto.interests
//         ?.map((item) => item.trim())
//         .filter(Boolean),

//       genderPreference: dto.genderPreference,

//       goal: dto.goal?.trim(),

//       matchType: dto.matchType ?? 'random',
//     });
//   }

//   @Post('cancel')
//   @HttpCode(200)
//   @ApiOperation({
//     summary: 'Cancel active matchmaking search',
//   })
//   async cancel(@CurrentUser('id') userId: string) {
//     return this.matchmaking.cancel(userId);
//   }

//   @Post('status')
//   @HttpCode(200)
//   @ApiOperation({
//     summary: 'Get current matchmaking status',
//   })
//   async status(@CurrentUser('id') userId: string) {
//     return this.matchmaking.getStatus(userId);
//   }

//   private parsePreferredLevel(
//     input?: string,
//   ): { min?: string; max?: string } | undefined {
//     if (!input) {
//       return undefined;
//     }

//     const parts = input
//       .split('-')
//       .map((value) => value.trim().toUpperCase());

//     if (parts.length !== 2) {
//       return undefined;
//     }

//     const [min, max] = parts;

//     const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

//     if (!levels.includes(min) || !levels.includes(max)) {
//       return undefined;
//     }

//     const minIndex = levels.indexOf(min);
//     const maxIndex = levels.indexOf(max);

//     if (minIndex > maxIndex) {
//       return undefined;
//     }

//     return {
//       min,
//       max,
//     };
//   }
// }

import {
  Body,
  Controller,
  HttpCode,
  Post,
  UseGuards,
} from "@nestjs/common";

import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
} from "@nestjs/swagger";

import {
  IsArray,
  IsIn,
  IsOptional,
  IsString,
} from "class-validator";

import { CurrentUser } from "../common/decorators/current-user.decorator";
import { JwtAuthGuard } from "../common/guards/jwt-auth.guard";
import { MatchmakingService } from "./matchmaking.service";

class StartMatchDto {
  @IsOptional()
  @IsString()
  language?: string;

  @IsOptional()
  @IsString()
  level?: string;

  /**
   * Example:
   * "A2-C1"
   */
  @IsOptional()
  @IsString()
  preferredLevel?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  interests?: string[];

  @IsOptional()
  @IsIn(["MALE", "FEMALE", "any"])
  genderPreference?: "MALE" | "FEMALE" | "any";

  @IsOptional()
  @IsString()
  goal?: string;

  @IsOptional()
  @IsIn([
    "random",
    "level",
    "interview",
    "business",
    "casual",
  ])
  matchType?: string;
}

@ApiTags("matchmaking")
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller("matchmaking")
export class MatchmakingController {
  constructor(
    private readonly matchmaking: MatchmakingService,
  ) {}

  /**
   * Start matchmaking search.
   *
   * POST /matchmaking/start
   */
  @Post("start")
  @HttpCode(200)
  @ApiOperation({
    summary:
      "Start searching for a conversation partner",
  })
  async start(
    @CurrentUser("id") userId: string,
    @Body() dto: StartMatchDto,
  ) {
    const preferredLevel =
      this.parsePreferredLevel(
        dto.preferredLevel,
      );

    return this.matchmaking.start(
      userId,
      {
        language:
          dto.language
            ?.trim()
            .toLowerCase(),

        level:
          dto.level
            ?.trim()
            .toUpperCase(),

        preferredLevel,

        interests:
          dto.interests
            ?.map(
              (item) =>
                item.trim(),
            )
            .filter(
              Boolean,
            ),

        genderPreference:
          dto.genderPreference,

        goal:
          dto.goal
            ?.trim(),

        matchType:
          dto.matchType ??
          "random",
      },
    );
  }

  /**
   * Cancel matchmaking.
   *
   * POST /matchmaking/cancel
   */
  @Post("cancel")
  @HttpCode(200)
  @ApiOperation({
    summary:
      "Cancel active matchmaking search",
  })
  async cancel(
    @CurrentUser("id") userId: string,
  ) {
    return this.matchmaking.cancel(
      userId,
    );
  }

  /**
   * Recover current matchmaking state.
   *
   * POST /matchmaking/status
   */
  @Post("status")
  @HttpCode(200)
  @ApiOperation({
    summary:
      "Get current matchmaking status",
  })
  async status(
    @CurrentUser("id") userId: string,
  ) {
    return this.matchmaking.getStatus(
      userId,
    );
  }

  /**
   * Parse:
   *
   * A2-C1
   *
   * into:
   *
   * {
   *   min: "A2",
   *   max: "C1"
   * }
   */
  private parsePreferredLevel(
    input?: string,
  ): {
    min?: string;
    max?: string;
  } | undefined {
    if (!input) {
      return undefined;
    }

    const parts = input
      .split("-")
      .map(
        (value) =>
          value
            .trim()
            .toUpperCase(),
      );

    if (
      parts.length !== 2
    ) {
      return undefined;
    }

    const [min, max] = parts;

    const levels = [
      "A1",
      "A2",
      "B1",
      "B2",
      "C1",
      "C2",
    ];

    if (
      !levels.includes(min) ||
      !levels.includes(max)
    ) {
      return undefined;
    }

    const minIndex =
      levels.indexOf(min);

    const maxIndex =
      levels.indexOf(max);

    if (
      minIndex > maxIndex
    ) {
      return undefined;
    }

    return {
      min,
      max,
    };
  }
}