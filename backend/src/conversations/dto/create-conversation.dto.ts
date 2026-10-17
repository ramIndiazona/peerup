import { IsOptional, IsUUID } from 'class-validator';

export class CreateConversationDto {
  @IsUUID()
  friendId!: string;

  @IsOptional()
  @IsUUID()
  callId?: string;
}