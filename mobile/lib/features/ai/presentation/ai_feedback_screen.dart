import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/load_state.dart';
import '../../../core/widgets/async_content.dart';
import '../../../core/widgets/loading_button.dart';
import '../bloc/ai_feedback_cubit.dart';
import '../bloc/ai_session_cubit.dart';

class AIFeedbackScreen extends StatelessWidget {
  const AIFeedbackScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Your feedback')),
      body: BlocBuilder<AIFeedbackCubit, LoadState<dynamic>>(
        builder: (context, feedback) {
          return AsyncContent<dynamic>(
            value: feedback,
            data: (data) {
              final map = (data as Map).cast<String, dynamic>();
              final score = map['overallScore'];
              final words = (map['wordsToLearn'] as List?)?.cast<String>();
              final suggestions =
                  (map['suggestedSentences'] as List?)?.cast<String>();
              final keySections = [
                'grammarFeedback',
                'vocabularyFeedback',
                'fluencyFeedback',
                'pronunciationFeedback',
              ];

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (score is num) ...[
                    Center(
                      child: Text(
                        '$score / 10',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: LinearProgressIndicator(
                        value: score.clamp(0, 10).toDouble() / 10,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (words != null && words.isNotEmpty) ...[
                    const _SectionTitle('Words to learn'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final w in words)
                          Chip(
                            label: Text(w),
                            avatar: const Icon(
                              Icons.bookmark_add_outlined,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (suggestions != null && suggestions.isNotEmpty) ...[
                    const _SectionTitle('Suggested sentences'),
                    for (final s in suggestions)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            '“$s”',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                  ],
                  for (final key in keySections)
                    if (map[key] != null)
                      _FeedbackCard(title: _label(key), value: map[key]),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LoadingButton(
            label: 'Done',
            onPressed: () {
              context.read<AISessionCubit>().reset();
              context.go(AppRoutes.homeAi);
            },
          ),
        ),
      ),
    );
  }

  String _label(String key) => switch (key) {
    'grammarFeedback' => 'Grammar',
    'vocabularyFeedback' => 'Vocabulary',
    'fluencyFeedback' => 'Fluency',
    'pronunciationFeedback' => 'Pronunciation',
    _ => key,
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.title, required this.value});

  final String title;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String text;
    if (value is String) {
      text = value;
    } else if (value is Map) {
      final score = value['score'];
      final message = value['message'] ?? value['comment'] ?? value['feedback'];
      text = [
        if (score != null) 'Score: $score',
        if (message != null) '$message',
      ].join('\n');
    } else {
      text = '$value';
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
