import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { EnglishLevel, Gender } from '@prisma/client';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'Alex' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  name?: string;

  @ApiPropertyOptional({ example: 'https://cdn.example.com/avatars/a.png' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  avatar?: string;

  @ApiPropertyOptional({ enum: Gender })
  @IsOptional()
  @IsIn(Object.values(Gender))
  gender?: Gender;

  @ApiPropertyOptional({ example: '1996-04-12' })
  @IsOptional()
  @IsDateString()
  dateOfBirth?: string;

  @ApiPropertyOptional({ example: 'Brazil' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  country?: string;

  @ApiPropertyOptional({ example: 'Portuguese' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  nativeLanguage?: string;

  @ApiPropertyOptional({ example: 'English' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  learningLanguage?: string;

  @ApiPropertyOptional({ enum: EnglishLevel, example: EnglishLevel.B1 })
  @IsOptional()
  @IsIn(Object.values(EnglishLevel))
  englishLevel?: EnglishLevel;

  @ApiPropertyOptional({ example: 'I want to speak with confidence.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

  @ApiPropertyOptional({ example: ['Improve speaking confidence', 'Prepare for travel'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(40, { each: true })
  conversationGoals?: string[];

  @ApiPropertyOptional({ example: ['technology', 'movies', 'travel'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  interests?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  showAge?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  showGender?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  onboardingCompleted?: boolean;
}

export class PublicProfileDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiPropertyOptional()
  avatar?: string | null;

  @ApiProperty({ enum: EnglishLevel })
  englishLevel!: EnglishLevel;

  @ApiProperty()
  nativeLanguage!: string;

  @ApiPropertyOptional()
  country?: string | null;

  @ApiPropertyOptional()
  bio?: string | null;

  @ApiPropertyOptional()
  yearsOld?: number | null;

  @ApiPropertyOptional()
  gender?: Gender | null;

  @ApiProperty({ type: [String] })
  interests!: string[];

  @ApiProperty({ type: [String] })
  conversationGoals!: string[];
}