import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail,
  IsIn,
  IsOptional,
  ValidateIf,
  IsString,
  IsStrongPassword,
  MaxLength,
  MinLength,
} from 'class-validator';
import { ALLOWED_AVATARS } from '../../common/constants/profile-avatars';
import { EnglishLevel, Gender } from '@prisma/client';

export class RegisterDto {
  @ApiPropertyOptional({ enum: ALLOWED_AVATARS, example: 'avatar_03' })
  @ValidateIf((_object, value) => value !== undefined)
  @IsString()
  @IsIn(ALLOWED_AVATARS)
  avatar?: string;

  @ApiProperty({ example: 'alex@example.com' })
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @ApiProperty({ example: '+15551235678' })
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(32)
  phone?: string;

  @ApiProperty({ minLength: 8, example: 'SuperSecret123' })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  @IsStrongPassword({ minSymbols: 0, minUppercase: 1, minNumbers: 1, minLowercase: 1 })
  password!: string;

  @ApiProperty({ example: 'Alex' })
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  name!: string;

  @ApiPropertyOptional({ enum: Gender })
  @IsOptional()
  @IsIn(Object.values(Gender))
  gender?: Gender;

  @ApiPropertyOptional({ enum: EnglishLevel })
  @IsOptional()
  @IsIn(Object.values(EnglishLevel))
  englishLevel?: EnglishLevel;
}

export class LoginDto {
  @ApiProperty({ example: 'alex@example.com' })
  @IsEmail()
  email!: string;

  @ApiProperty({ example: 'SuperSecret123' })
  @IsString()
  password!: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  refreshToken!: string;
}

export class TokenResponseDto {
  @ApiProperty()
  accessToken!: string;

  @ApiProperty()
  refreshToken!: string;

  @ApiProperty()
  expiresInSeconds!: number;

  @ApiProperty()
  tokenType!: string;
}