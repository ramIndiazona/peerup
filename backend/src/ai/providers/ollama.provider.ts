import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
    LLMService,
    LLMMessage,
} from '../interfaces/ai-providers.interface';

@Injectable()
export class OllamaProviderService implements LLMService {
    private readonly logger = new Logger(OllamaProviderService.name);

    private readonly baseUrl: string;
    private readonly model: string;

    constructor(private readonly config: ConfigService) {
        this.baseUrl = config.get<string>(
            'ai.ollamaUrl',
            'http://localhost:11434',
        );

        this.model = config.get<string>(
            'ai.ollamaModel',
            'gemma4:e2b',
        );

        this.logger.log(`Ollama URL: ${this.baseUrl}`);
        this.logger.log(`Ollama model: ${this.model}`);
    }

    async chat(
        messages: LLMMessage[],
        opts?: {
            temperature?: number;
            maxTokens?: number;
        },
    ): Promise<{ text: string }> {
        this.logger.log(`Calling Ollama: ${this.baseUrl}`);
        this.logger.log(`Model: ${this.model}`);

        const response = await fetch(`${this.baseUrl}/api/chat`, {
            method: 'POST',

            headers: {
                'Content-Type': 'application/json',
            },

            body: JSON.stringify({
                model: this.model,
                messages,
                stream: false,

                // IMPORTANT:
                // Gemma 4 thinking was consuming the whole token budget.
                think: false,

                options: {
                    temperature: opts?.temperature ?? 0.7,
                    num_predict: Math.max(opts?.maxTokens ?? 300, 300),
                },
            }),
        });

        const rawResponse = await response.text();

        this.logger.log(`Ollama status: ${response.status}`);
        this.logger.log(`Ollama raw response: ${rawResponse}`);

        if (!response.ok) {
            throw new Error(
                `Ollama API error ${response.status}: ${rawResponse}`,
            );
        }

        const data = JSON.parse(rawResponse);

        const text = data?.message?.content ?? '';

        this.logger.log(
            `Ollama extracted text: ${JSON.stringify(text)}`,
        );

        return {
            text,
        };
    }
}