import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  LLMService,
  LLMMessage,
} from '../interfaces/ai-providers.interface';

/**
 * Deterministic rule-based LLM used ONLY when no AI provider is configured
 * (e.g. local development with no API key) OR when the network is unavailable.
 * It is intentionally a trivial echo/summary engine and is never presented as
 * a real AI provider. Enabled only when AI_PROVIDER=local.
 */
@Injectable()
export class LocalLlmService implements LLMService {
  private readonly logger = new Logger(LocalLlmService.name);

  constructor(config: ConfigService) {
    if (config.get<string>('ai.provider') === 'local') {
      this.logger.warn('Running with local echo LLM. Configure OPENAI_API_KEY for production.');
    }
  }

  async chat(messages: LLMMessage[]): Promise<{ text: string }> {
    const last = [...messages].reverse().find((m) => m.role === 'user');
    const system = messages.find((m) => m.role === 'system')?.content ?? '';
    const user = last?.content?.trim() ?? '';
    if (!user) return { text: '' };
    return {
      text: this.echoResponse(system, user),
    };
  }

  private echoResponse(system: string, user: string): string {
    const short = user.length > 220 ? `${user.slice(0, 220)}...` : user;
    return `[local-mode] Interesting answer: "${short}" — practice repeating this phrase naturally.`;
  }
}