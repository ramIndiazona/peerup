/**
 * AI provider boundaries. Business logic (AISessionsService) depends only on
 * these interfaces; swapping providers is configuration, not code changes.
 */

export interface TranscriptEntry {
  role: 'user' | 'assistant';
  content: string;
  at: string;
}

export interface SpeechToTextResult {
  text: string;
  confidence?: number;
}

export interface SpeechToTextService {
  transcribe(opts: {
    audioBase64: string;
    mime?: string;
    language?: string;
  }): Promise<SpeechToTextResult>;
}

export interface LLMMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface LLMService {
  chat(
    messages: LLMMessage[],
    opts?: { temperature?: number; maxTokens?: number },
  ): Promise<{ text: string }>;
}

export interface TextToSpeechResult {
  audioBase64: string;
  mime: string;
}

export interface VoiceConfig {
  voice?: string;
  speed?: number;
  model?: string;
}

export interface TextToSpeechService {
  synthesize(opts: {
    text: string;
    voice?: VoiceConfig;
  }): Promise<TextToSpeechResult>;
}

export interface PronunciationIssue {
  word: string;
  suggestion: string;
  tip: string;
}

export interface PronunciationAnalysisService {
  analyze(opts: {
    transcript: TranscriptEntry[];
    language: string;
  }): Promise<{
    score: number;
    issues: PronunciationIssue[];
    summary: string;
  }>;
}

// ------------------- Provider tokens -------------------

export const STT_SERVICE = 'STT_SERVICE';
export const LLM_SERVICE = 'LLM_SERVICE';
export const TTS_SERVICE = 'TTS_SERVICE';
export const PRONUNCIATION_SERVICE = 'PRONUNCIATION_SERVICE';
export const MODERATION_SERVICE = 'MODERATION_SERVICE';