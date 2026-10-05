import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_button.dart';
import '../bloc/ai_session_cubit.dart';

/// Feedback shown after the user ends a Practice session.
///
/// Only real session data is rendered (character, scenario, duration) and the
/// rating chips are multi-select.
class PracticeFeedbackScreen extends StatefulWidget {
  const PracticeFeedbackScreen({super.key, required this.sessionId});

  final String sessionId;

  static const List<String> options = [
    'Friendly',
    'Excellent speaker',
    'Good listener',
    'Easy to talk to',
    'Helpful',
    'Funny',
    'Confident',
    'Great conversation',
  ];

  @override
  State<PracticeFeedbackScreen> createState() => _PracticeFeedbackScreenState();
}

class _PracticeFeedbackScreenState extends State<PracticeFeedbackScreen> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.read<AISessionCubit>().state;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgLight,
        title: const Text('Practice Complete'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'How was your conversation?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in PracticeFeedbackScreen.options)
                  FilterChip(
                    label: Text(option),
                    selected: _selected.contains(option),
                    onSelected:
                        (isSelected) => setState(() {
                          if (isSelected) {
                            _selected.add(option);
                          } else {
                            _selected.remove(option);
                          }
                        }),
                  ),
              ],
            ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Selected: ${_selected.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 28),
            Text(
              'Session',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.face_retouching_natural_rounded,
              label: 'Character',
              value: session.character?.name,
            ),
            _InfoCard(
              icon: Icons.theater_comedy_outlined,
              label: 'Scenario',
              value: session.scenario,
            ),
            _InfoCard(
              icon: Icons.timer_outlined,
              label: 'Duration',
              value: _duration(session),
            ),
            _InfoCard(
              icon: Icons.tag_rounded,
              label: 'Session ID',
              value: widget.sessionId,
            ),
          ],
        ),
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

  String? _duration(AISessionControllerState session) {
    final startedAt = session.startedAt;
    if (startedAt == null) return null;

    final seconds = DateTime.now().difference(startedAt).inSeconds;
    if (seconds < 60) return '${seconds}s';

    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return rest == 0 ? '${minutes}m' : '${minutes}m ${rest}s';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = value;

    if (text == null || text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
