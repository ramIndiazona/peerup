import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LLMService, LLM_SERVICE } from './interfaces/ai-providers.interface';

export interface ModerationResult {
  safe: boolean;
  flags: string[];
}

/**
 * Basic moderation for AI-generated text and user messages in AI sessions.
 * Uses an LLM judgement call when AI_MODERATION_ENABLED=true; otherwise a
 * lightweight keyword filter is applied.
 */
@Injectable()
export class ModerationService {
  private readonly enabled: boolean;
  private readonly keywordFilters: string[];

  constructor(
    @Inject(LLM_SERVICE) private readonly llm: LLMService,
    config: ConfigService,
  ) {
    this.enabled = config.get<boolean>('ai.moderationEnabled', false);
    this.keywordFilters = [
      'self-harm',
      'suicide',
      'kill yourself',
    ];
  }

  async moderate(text: string, context: 'ai' | 'user'): Promise<ModerationResult> {
    const flags = this.keywordFilter(text);
    if (flags.length > 0) return { safe: false, flags };

    if (this.enabled) {
      try {
        const res = await this.llm.chat(
          [
            {
              role: 'system',
              content:
                'You are a safety moderator. Determine if the text contains harassment, abuse, spam, dangerous content, or inappropriate behavior for a language-learning app. Respond with JSON: {"safe": boolean, "flags": string[]}',
            },
            { role: 'user', content: text },
          ],
          { temperature: 0, maxTokens: 100 },
        );
        const parsed = JSON.parse(res.text);
        return { safe: Boolean(parsed.safe), flags: parsed.flags ?? [] };
      } catch {
        return { safe: true, flags };
      }
    }
    return { safe: true, flags };
  }

  private keywordFilter(text: string): string[] {
    const lower = text.toLowerCase();
    return this.keywordFilters.filter((k) => lower.includes(k));
  }
}