import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import OpenAI from 'openai';
import {
  LLMService,
  LLMMessage,
  SpeechToTextService,
  SpeechToTextResult,
  TextToSpeechService,
  TextToSpeechResult,
  VoiceConfig,
  TranscriptEntry,
  PronunciationAnalysisService,
} from '../interfaces/ai-providers.interface';

@Injectable()
export class OpenAiProviderService
  implements LLMService, SpeechToTextService, TextToSpeechService, PronunciationAnalysisService
{
  private readonly logger = new Logger(OpenAiProviderService.name);
  private readonly client: OpenAI;
  private readonly model: string;
  private readonly feedbackModel: string;

  constructor(config: ConfigService) {
    this.model = config.get<string>('ai.openaiModel', 'gpt-4o-mini');
    this.feedbackModel = config.get<string>('ai.feedbackModel', 'gpt-4o-mini');
    const apiKey = config.get<string>('ai.openaiApiKey');
    if (!apiKey) {
      this.logger.warn('OPENAI_API_KEY not configured; AI features will fail at runtime');
    }
    this.client = new OpenAI({ apiKey: apiKey ?? 'missing-key' });
  }

  // ---------- LLM ----------

  async chat(
    messages: LLMMessage[],
    opts?: { temperature?: number; maxTokens?: number },
  ): Promise<{ text: string }> {
    const completion = await this.client.chat.completions.create({
      model: this.model,
      messages: messages as any,
      temperature: opts?.temperature ?? 0.7,
      max_tokens: opts?.maxTokens ?? 500,
    });
    const text = completion.choices[0]?.message?.content ?? '';
    return { text };
  }

  // ---------- Speech-to-Text ----------

  async transcribe(opts: {
    audioBase64: string;
    mime?: string;
    language?: string;
  }): Promise<SpeechToTextResult> {
    const buffer = Buffer.from(opts.audioBase64, 'base64');
    const ext = this.extForMime(opts.mime);
    const file = new globalThis.File([buffer], `audio${ext}`, {
      type: opts.mime ?? 'audio/webm',
    });
    const response = await this.client.audio.transcriptions.create({
      file,
      model: 'whisper-1',
      language: opts.language?.slice(0, 2) ?? 'en',
    });
    return { text: response.text, confidence: undefined };
  }

  // ---------- Text-to-Speech ----------

  async synthesize(opts: { text: string; voice?: VoiceConfig }): Promise<TextToSpeechResult> {
    const response = await this.client.audio.speech.create({
      model: opts.voice?.model ?? 'tts-1',
      voice: (opts.voice?.voice ?? 'alloy') as any,
      input: opts.text,
      speed: opts.voice?.speed ?? 1,
      response_format: 'mp3',
    });
    const arrayBuffer = await response.arrayBuffer();
    return {
      audioBase64: Buffer.from(arrayBuffer).toString('base64'),
      mime: 'audio/mpeg',
    };
  }

  // ---------- Pronunciation analysis (prompt-graded, clearly learning feedback) ----------

  async analyze(opts: {
    transcript: TranscriptEntry[];
    language: string;
  }): Promise<{ score: number; issues: { word: string; suggestion: string; tip: string }[]; summary: string }> {
    const userText = opts.transcript
      .filter((e) => e.role === 'user')
      .map((e) => e.content)
      .join('\n');

    const prompt = [
      'You are a pronunciation coach for an English learner. Analyze the learner speech.',
      'Return STRICT JSON with no markdown:',
      '{"score": 0-100, "summary": "one sentence", "issues": [{"word": string, "suggestion": string, "tip": string}]}',
      'Focus on common pronunciation problems (TH sounds, consonant clusters, vowel length, word stress).',
      `Language level context: ${opts.language}.`,
      'Learner speech:',
      userText || '(none provided)',
    ].join('\n');

    const result = await this.chat(
      [{ role: 'system', content: 'You return only valid JSON.' }, { role: 'user', content: prompt }],
      { temperature: 0.2, maxTokens: 700 },
    );
    try {
      return JSON.parse(result.text);
    } catch {
      return {
        score: 0,
        issues: [],
        summary: 'Pronunciation analysis unavailable.',
      };
    }
  }

  private extForMime(mime?: string): string {
    if (!mime) return '.webm';
    if (mime.includes('ogg')) return '.ogg';
    if (mime.includes('mpeg') || mime.includes('mp3')) return '.mp3';
    if (mime.includes('wav')) return '.wav';
    return '.webm';
  }
}