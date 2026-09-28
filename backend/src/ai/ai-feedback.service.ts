import { Inject, Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  LLMService,
  LLM_SERVICE,
} from './interfaces/ai-providers.interface';
import { TranscriptEntry } from './interfaces/ai-providers.interface';
import { AIFeedback, AISession } from '@prisma/client';

export interface FeedbackInput {
  session: AISession;
  transcript: TranscriptEntry[];
  wordCount: number;
}

@Injectable()
export class AIFeedbackService {
  private readonly logger = new Logger(AIFeedbackService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(LLM_SERVICE) private readonly llm: LLMService,
  ) {}

  async generate(userId: string, input: FeedbackInput): Promise<AIFeedback> {
    const userLines = input.transcript
      .filter((t) => t.role === 'user')
      .map((t) => t.content)
      .join('\n');

    const prompt = [
      'You are an English learning coach. Produce feedback for a learner conversation.',
      'Return STRICT JSON — no markdown — with this shape:',
      `{
        "overallScore": 0-100,
        "grammar": { "strengths": string[], "errors": [{"original": string, "suggested": string, "explanation": string}] },
        "vocabulary": { "strengths": string[], "suggestions": string[] },
        "fluency": { "score": 0-100, "comment": string },
        "pronunciationFocus": string,
        "suggestedSentences": string[],
        "wordsToLearn": string[],
        "summary": string
      }`,
      'Scores are app-generated learning feedback, not medical/scientific assessments.',
      'Learner utterance(s):',
      userLines || '(no learner speech recorded)',
    ].join('\n');

    let parsed: any = {};
    try {
      const res = await this.llm.chat(
        [
          { role: 'system', content: 'You always return valid JSON only.' },
          { role: 'user', content: prompt },
        ],
        { temperature: 0.2, maxTokens: 1500 },
      );
      parsed = JSON.parse(res.text);
    } catch (err) {
      this.logger.warn(`Feedback parse failed: ${(err as Error).message}`);
      parsed = {
        overallScore: null,
        grammar: { strengths: [], errors: [] },
        vocabulary: { strengths: [], suggestions: [] },
        fluency: { score: null, comment: 'Fluency feedback unavailable.' },
        pronunciationFocus: '',
        suggestedSentences: [],
        wordsToLearn: [],
        summary: 'Feedback could not be generated at this time.',
      };
    }

    return this.prisma.aIFeedback.create({
      data: {
        userId,
        aiSessionId: input.session.id,
        overallScore: parsed.overallScore ?? null,
        grammarFeedback: parsed.grammar ?? {},
        vocabularyFeedback: parsed.vocabulary ?? {},
        fluencyFeedback: parsed.fluency ?? {},
        pronunciationFeedback: { focus: parsed.pronunciationFocus ?? '' },
        suggestedSentences: parsed.suggestedSentences ?? [],
        wordsToLearn: parsed.wordsToLearn ?? [],
      },
    });
  }
}