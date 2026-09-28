import { Injectable, Logger } from '@nestjs/common';
import { AISessionStatus, UsageKind, SubscriptionPlan } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { notFound, conflict, forbidden } from '../common/errors/api.exception';
import { UsageService } from '../subscriptions/usage.service';
import {
  LLMService,
  LLM_SERVICE,
  STT_SERVICE,
  TTS_SERVICE,
  PRONUNCIATION_SERVICE,
  SpeechToTextService,
  TextToSpeechService,
  PronunciationAnalysisService,
  TranscriptEntry,
  LLMMessage,
} from './interfaces/ai-providers.interface';
import { ModerationService } from './moderation.service';
import { AICharactersService } from './ai-characters.service';
import { AIFeedbackService } from './ai-feedback.service';
import { Inject } from '@nestjs/common';

interface OutgoingReply {
  text: string;
  audioBase64?: string;
  mime?: string;
}

@Injectable()
export class AISessionsService {
  private readonly logger = new Logger(AISessionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly usage: UsageService,
    private readonly moderation: ModerationService,
    private readonly characters: AICharactersService,
    private readonly feedbackService: AIFeedbackService,
    @Inject(STT_SERVICE) private readonly stt: SpeechToTextService,
    @Inject(TTS_SERVICE) private readonly tts: TextToSpeechService,
    @Inject(PRONUNCIATION_SERVICE) private readonly pronunciation: PronunciationAnalysisService,
    @Inject(LLM_SERVICE) private readonly llm: LLMService,
  ) { }

  // async start(userId: string, dto: { characterId?: string; scenario?: string }) {
  //   const plan = await this.usage.getPlan(userId);
  //   if (plan !== SubscriptionPlan.PREMIUM) 
  //     {
  //     // return plain sessions for free users too; limits decide the count later
  //   }

  //   const characters = await this.characters.list(true);
  //   const character = dto.characterId
  //     ? await this.characters.getActive(dto.characterId)
  //     : characters.find((c) => c.scenario === dto.scenario);
  //   if (!character && !dto.scenario) {
  //     throw notFound('CHARACTER_NOT_FOUND', 'No AI character selected');
  //   }

  //   const live = await this.prisma.aISession.findFirst({
  //     where: { userId, status: AISessionStatus.ACTIVE },
  //     orderBy: { startedAt: 'desc' },
  //   });
  //   if (live) {
  //     // Resume semantics: return actual active session on conflicting start.
  //     return { session: live, resumed: true };
  //   }

  //   const session = await this.prisma.aISession.create({
  //     data: {
  //       userId,
  //       characterId: character?.id,
  //       status: AISessionStatus.ACTIVE,
  //       transcript: [],
  //     },
  //   });
  //   return { session, resumed: false };
  // }

  // async start(
  //   userId: string,
  //   dto: { characterId?: string; scenario?: string },
  // ) {
  //   const plan = await this.usage.getPlan(userId);

  //   if (plan !== SubscriptionPlan.PREMIUM) {
  //     // Free users are also allowed to start sessions.
  //     // Usage limits are enforced while messaging.
  //   }

  //   const characters = await this.characters.list(true);

  //   const character = dto.characterId
  //     ? await this.characters.getActive(dto.characterId)
  //     : characters.find((c) => c.scenario === dto.scenario);

  //   if (!character && !dto.scenario) {
  //     throw notFound(
  //       'CHARACTER_NOT_FOUND',
  //       'No AI character selected',
  //     );
  //   }

  //   /*
  //    * Check whether the user already has an active session.
  //    */
  //   const live = await this.prisma.aISession.findFirst({
  //     where: {
  //       userId,
  //       status: AISessionStatus.ACTIVE,
  //     },
  //     include: {
  //       character: true,
  //     },
  //     orderBy: {
  //       startedAt: 'desc',
  //     },
  //   });

  //   /*
  //    * If there is an active session for the SAME character,
  //    * resume it.
  //    */
  //   if (
  //     live &&
  //     character &&
  //     live.characterId === character.id
  //   ) {
  //     return {
  //       session: live,
  //       resumed: true,
  //     };
  //   }

  //   /*
  //    * If the user selected a DIFFERENT character,
  //    * close the previous active session first.
  //    */
  //   if (live) {
  //     await this.prisma.aISession.update({
  //       where: {
  //         id: live.id,
  //       },
  //       data: {
  //         status: AISessionStatus.ENDED,
  //         endedAt: new Date(),
  //       },
  //     });
  //   }

  //   /*
  //    * Create a completely new session.
  //    */
  //   const session = await this.prisma.aISession.create({
  //     data: {
  //       userId,
  //       characterId: character?.id,
  //       status: AISessionStatus.ACTIVE,
  //       transcript: [],
  //       wordCount: 0,
  //     },
  //     include: {
  //       character: true,
  //     },
  //   });

  //   return {
  //     session,
  //     resumed: false,
  //   };
  // }

  async start(
    userId: string,
    dto: {
      characterId?: string;
      scenario?: string;
    },
  ) {
    const plan = await this.usage.getPlan(userId);

    if (plan !== SubscriptionPlan.PREMIUM) {
      // Free users are also allowed to start sessions.
      // Usage limits are enforced while messaging.
    }

    const characters =
      await this.characters.list();

    const character = dto.characterId
      ? await this.characters.getActive(
        dto.characterId,
      )
      : characters.find(
        (c) => c.scenario === dto.scenario,
      );

    if (!character && !dto.scenario) {
      throw notFound(
        'CHARACTER_NOT_FOUND',
        'No AI character selected',
      );
    }

    // ==========================================
    // ALWAYS CREATE A NEW SESSION
    // ==========================================

    const session =
      await this.prisma.aISession.create({
        data: {
          userId,
          characterId: character?.id,
          status: AISessionStatus.ACTIVE,

          // Empty transcript.
          transcript: [],

          wordCount: 0,
        },

        include: {
          character: true,
        },
      });

    return {
      session,
      resumed: false,
    };
  }

  // async message(userId: string, sessionId: string, dto: { text?: string; audioBase64?: string; mime?: string; durationSeconds?: number }) {
  //   const session = await this.prisma.aISession.findFirst({
  //     where: { id: sessionId, userId },
  //     include: { character: true },
  //   });
  //   if (!session) throw notFound('SESSION_NOT_FOUND', 'AI session not found');
  //   if (session.status !== AISessionStatus.ACTIVE) {
  //     throw conflict('SESSION_ENDED', 'This session has ended');
  //   }

  //   // Transcribe audio input if provided.
  //   let text = dto.text ?? '';
  //   if (!text && dto.audioBase64) {
  //     const stt = await this.stt.transcribe({
  //       audioBase64: dto.audioBase64,
  //       mime: dto.mime,
  //       language: 'en',
  //     });
  //     text = stt.text;
  //   }
  //   text = text.trim();
  //   if (!text) {
  //     throw conflict('EMPTY_MESSAGE', 'No speech detected');
  //   }

  //   // Usage gate: count conversation + seconds.
  //   const convLimit = await this.usage.checkAndIncrement(userId, UsageKind.AI_CONVERSATION, 1);
  //   if (!convLimit.allowed) {
  //     throw forbidden('DAILY_LIMIT_REACHED', 'Daily AI conversation limit reached');
  //   }
  //   if ((dto.durationSeconds ?? 0) > 0) {
  //     await this.usage.checkAndIncrement(
  //       userId,
  //       UsageKind.AI_SECONDS,
  //       Math.round(dto.durationSeconds as number),
  //     );
  //   }

  //   // Moderation for user text.
  //   const moderatedUser = await this.moderation.moderate(text, 'user');
  //   if (!moderatedUser.safe) {
  //     throw forbidden('CONTENT_BLOCKED', 'This message was blocked by safety filters');
  //   }

  //   const transcript = (session.transcript ?? []) as unknown as TranscriptEntry[];
  //   transcript.push({ role: 'user', content: text, at: new Date().toISOString() });

  //   // Build prompt from character system prompt + conversation history.
  //   const systemPrompt =
  //     session.character?.systemPrompt ??
  //     `You are an English conversation partner for a learner (level ${'B1'}). Keep replies short, natural, encouraging. Correct gently when needed. Stay in character for scenario: ${session.character?.scenario ?? 'daily'}. Do not break character or mention being an AI helper unless asked.`;

  //   const llm = await this.llm.chat(
  //     [
  //       { role: 'system', content: systemPrompt },
  //       ...transcript
  //         .slice(-16)
  //         .map((t) => ({ role: t.role === 'user' ? ('user' as const) : ('assistant' as const), content: t.content })),
  //     ],
  //     { temperature: 0.8, maxTokens: 240 },
  //   );

  //   // Moderation for AI output.
  //   const moderatedAi = await this.moderation.moderate(llm.text, 'ai');

  //   const reply: OutgoingReply = {
  //     text: moderatedAi.safe ? llm.text : 'I am not able to continue this topic. Let us practice something else.',
  //   };
  //   transcript.push({ role: 'assistant', content: reply.text, at: new Date().toISOString() });
  //   const wordCount = transcript.reduce((sum, t) => sum + t.content.split(/\s+/).length, 0);

  //   await this.prisma.aISession.update({
  //     where: { id: sessionId },
  //     data: { transcript: transcript as any, wordCount },
  //   });

  //   return { reply: reply.text };
  // }


  async message(
    userId: string,
    sessionId: string,
    dto: {
      text?: string;
      audioBase64?: string;
      mime?: string;
      durationSeconds?: number;
    },
  ) {
    const session = await this.prisma.aISession.findFirst({
      where: {
        id: sessionId,
        userId,
      },
      include: {
        character: true,
      },
    });

    if (!session) {
      throw notFound(
        'SESSION_NOT_FOUND',
        'AI session not found',
      );
    }

    if (session.status !== AISessionStatus.ACTIVE) {
      throw conflict(
        'SESSION_ENDED',
        'This session has ended',
      );
    }

    // ==========================================
    // GET USER TEXT
    // ==========================================

    let text = dto.text ?? '';

    if (!text && dto.audioBase64) {
      const stt = await this.stt.transcribe({
        audioBase64: dto.audioBase64,
        mime: dto.mime,
        language: 'en',
      });

      text = stt.text;
    }

    text = text.trim();

    if (!text) {
      throw conflict(
        'EMPTY_MESSAGE',
        'No speech detected',
      );
    }

    // ==========================================
    // USAGE
    // ==========================================

    const convLimit =
      await this.usage.checkAndIncrement(
        userId,
        UsageKind.AI_CONVERSATION,
        1,
      );

    if (!convLimit.allowed) {
      throw forbidden(
        'DAILY_LIMIT_REACHED',
        'Daily AI conversation limit reached',
      );
    }

    if ((dto.durationSeconds ?? 0) > 0) {
      await this.usage.checkAndIncrement(
        userId,
        UsageKind.AI_SECONDS,
        Math.round(
          dto.durationSeconds as number,
        ),
      );
    }

    // ==========================================
    // MODERATION
    // ==========================================

    const moderatedUser =
      await this.moderation.moderate(
        text,
        'user',
      );

    if (!moderatedUser.safe) {
      throw forbidden(
        'CONTENT_BLOCKED',
        'This message was blocked by safety filters',
      );
    }

    // ==========================================
    // CHARACTER SYSTEM PROMPT
    // ==========================================

    const systemPrompt =
      session.character?.systemPrompt ??
      `You are an English conversation partner for a learner (level B1).
Keep replies short, natural, encouraging.
Correct gently when needed.
Stay in character for scenario: ${session.character?.scenario ?? 'daily'
      }.
Do not break character or mention being an AI helper unless asked.`;

    // ==========================================
    // IMPORTANT:
    // NO PREVIOUS CHAT HISTORY
    // ==========================================

    const llm = await this.llm.chat(
      [
        {
          role: 'system',
          content: systemPrompt,
        },
        {
          role: 'user',
          content: text,
        },
      ],
      {
        temperature: 0.8,
        maxTokens: 100,
      },
    );

    // ==========================================
    // MODERATE AI RESPONSE
    // ==========================================

    const moderatedAi =
      await this.moderation.moderate(
        llm.text,
        'ai',
      );

    const reply: OutgoingReply = {
      text: moderatedAi.safe
        ? llm.text
        : 'I am not able to continue this topic. Let us practice something else.',
    };

    // ==========================================
    // NO TRANSCRIPT SAVE
    // ==========================================
    //
    // We intentionally DO NOT:
    //
    // transcript.push(...)
    // prisma.aISession.update(...)
    //
    // Therefore previous messages are not stored.
    //

    return {
      reply: reply.text,
    };
  }
  async end(userId: string, sessionId: string) {
    const session = await this.prisma.aISession.findFirst({
      where: { id: sessionId, userId },
      include: { character: true },
    });
    if (!session) throw notFound('SESSION_NOT_FOUND', 'AI session not found');
    if (session.status !== AISessionStatus.ACTIVE) {
      return { session, alreadyEnded: true };
    }

    const updated = await this.prisma.aISession.update({
      where: { id: sessionId },
      data: { status: AISessionStatus.ENDED, endedAt: new Date() },
    });
    return { session: updated };
  }

  async feedback(userId: string, sessionId: string): Promise<unknown> {
    const session = await this.prisma.aISession.findFirst({
      where: { id: sessionId, userId },
    });
    if (!session) throw notFound('SESSION_NOT_FOUND', 'AI session not found');

    const existing = await this.prisma.aIFeedback.findUnique({
      where: { aiSessionId: sessionId },
    });
    if (existing) return existing;
    if (session.status !== AISessionStatus.ENDED) {
      throw conflict('SESSION_ACTIVE', 'End the session to generate feedback');
    }

    const transcript = (session.transcript ?? []) as unknown as TranscriptEntry[];
    const feedback = await this.feedbackService.generate(userId, {
      session,
      transcript,
      wordCount: session.wordCount ?? 0,
    });
    return feedback;
  }
}