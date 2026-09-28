import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  LLM_SERVICE,
  PRONUNCIATION_SERVICE,
  STT_SERVICE,
  TTS_SERVICE,
} from './interfaces/ai-providers.interface';
import { OpenAiProviderService } from './providers/openai.provider';
import { LocalLlmService } from './providers/local-llm.provider';
import { ModerationService } from './moderation.service';
import { AIController } from './ai.controller';
import { AISessionsService } from './ai-sessions.service';
import { AICharactersService } from './ai-characters.service';
import { AIFeedbackService } from './ai-feedback.service';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';

@Module({
  imports: [SubscriptionsModule],
  controllers: [AIController],
  providers: [
    AISessionsService,
    AICharactersService,
    AIFeedbackService,
    {
      provide: LLM_SERVICE,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const provider = config.get<string>('ai.provider', 'openai');
        if (provider === 'local' || !config.get<string>('ai.openaiApiKey')) {
          return new LocalLlmService(config);
        }
        return new OpenAiProviderService(config);
      },
    },
    {
      provide: STT_SERVICE,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => new OpenAiProviderService(config),
    },
    {
      provide: TTS_SERVICE,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => new OpenAiProviderService(config),
    },
    {
      provide: PRONUNCIATION_SERVICE,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => new OpenAiProviderService(config),
    },
    ModerationService,
  ],
  exports: [AISessionsService, AICharactersService],
})
export class AIModule {}