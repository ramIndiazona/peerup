import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_content.dart';
import '../../../models/enums.dart';
import '../../../models/subscription.dart';
import '../bloc/premium_cubit.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final cubit = context.read<PremiumCubit>();
      if (!cubit.state.status.isLoaded && !cubit.state.status.isLoading) {
        cubit.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: BlocBuilder<PremiumCubit, PremiumState>(
        builder: (context, state) {
          final status = state.status.value;
          final usage = state.usage;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (status?.plan == SubscriptionPlan.premium) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Premium active',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            if (status?.renewsAt != null)
                              Text(
                                'Renews ${_fmt(status!.renewsAt!)}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'Your daily usage',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              AsyncContent<UsageResult>(
                value: usage,
                data:
                    (u) => Column(
                      children: [
                        for (final row in u.limits)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _UsageBar(row: row),
                          ),
                      ],
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                'Premium features',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: const [
                    _FeatureRow(
                      Icons.smart_toy_rounded,
                      'Up to 50 AI conversations / day',
                    ),
                    _FeatureRow(
                      Icons.timer_rounded,
                      '120 minutes of AI practice / day',
                    ),
                    _FeatureRow(
                      Icons.insights_rounded,
                      'Advanced grammar & pronunciation feedback',
                    ),
                    _FeatureRow(
                      Icons.workspace_premium_rounded,
                      'All premium AI characters',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (status?.plan != SubscriptionPlan.premium)
                FilledButton.icon(
                  onPressed: () async {
                    final result =
                        await context.read<PremiumCubit>().purchase();
                    if (!context.mounted) return;
                    if (result.mode == 'trial') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Premium trial started for ${result.premiumDays} days!',
                          ),
                        ),
                      );
                      await context.read<PremiumCubit>().load();
                    } else if (result.checkoutUrl != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Checkout flow will open here when a payment provider is wired.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text('Upgrade to Premium'),
                )
              else
                TextButton(
                  onPressed: () async {
                    await context.read<PremiumCubit>().cancel();
                  },
                  child: const Text(
                    'Cancel subscription',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.row});

  final UsageRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = row.limit == 0 ? 0.0 : (row.used / row.limit).clamp(0.0, 1.0);
    final label = switch (row.kind) {
      'VOICE_CALL' => 'Voice calls',
      'AI_CONVERSATION' => 'AI conversations',
      'AI_SECONDS' => 'AI practice time',
      _ => row.kind,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${row.used}/${row.limit}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 7,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: theme.colorScheme.outlineVariant.withValues(
            alpha: 0.4,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(text),
      dense: true,
    );
  }
}
