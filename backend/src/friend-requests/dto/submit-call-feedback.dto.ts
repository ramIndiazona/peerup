import {
  IsArray,
  IsBoolean,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class SubmitCallFeedbackDto {
  @IsString()
  @IsNotEmpty()
  receiverId!: string;

  @IsOptional()
  @IsIn(['LIKE', 'DISLIKE', 'like', 'dislike'])
  reaction?: string | null;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  feedback?: string[];

  @IsOptional()
  @IsBoolean()
  addToFriends?: boolean;

  @IsOptional()
  @IsBoolean()
  connectAgain?: boolean;

  @IsOptional()
  @IsString()
  callId?: string;
}
