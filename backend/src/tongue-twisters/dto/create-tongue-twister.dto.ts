
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CreateTongueTwisterDto {
  @IsString()
  @IsNotEmpty()
  title!: string;

  @IsString()
  @IsNotEmpty()
  text!: string;

  @IsOptional()
  @IsString()
  level?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  seconds?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  xp?: number;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsString()
  icon?: string;
}
