import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../features/premium/bloc/premium_cubit.dart';
import '../../../models/subscription.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';

/// The Premium subscription screen.
///
/// Displays the Monthly and Yearly plans, the current subscription status
/// and expiry date, and drives the Razorpay purchase flow through the
/// [SubscriptionBloc].
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<SubscriptionBloc>().add(const LoadSubscription());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SubscriptionBloc, SubscriptionState>(
      listener: _onStateChanged,
      child: Scaffold(
        appBar: AppBar(title: const Text('Premium Subscription')),
        body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
          builder: _buildBody,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SubscriptionState state) {
    final status = state is SubscriptionLoaded ? state.status : null;
    final isPremium = status?.isPremiumActive ?? false;
    final selected = state is SubscriptionLoaded ? state.selectedPeriod : null;
    final processing =
        state is SubscriptionPaymentProcessing ||
        state is SubscriptionPaymentVerification;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // ------------------------------------------------------------------
        // Current subscription status
        // ------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: isPremium ? AppColors.brandGradient : null,
            color: isPremium ? null : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(18),
            border:
                isPremium
                    ? null
                    : Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
          ),
          child: Row(
            children: [
              Icon(
                isPremium
                    ? Icons.workspace_premium_rounded
                    : Icons.payment_rounded,
                color:
                    isPremium
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                size: 34,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? 'Premium active' : 'Free plan',
                      style: TextStyle(
                        color:
                            isPremium
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isPremium && status?.renewsAt != null)
                      Text(
                        'Expires ${_fmt(status!.renewsAt!)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      )
                    else if (!isPremium)
                      Text(
                        'Upgrade to unlock Premium features',
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

        // ------------------------------------------------------------------
        // Plans
        // ------------------------------------------------------------------
        Text(
          'Choose a plan',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ...SubscriptionOption.all().map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlanCard(
              option: option,
              selected: selected == option.apiValue,
              onTap:
                  () => context.read<SubscriptionBloc>().add(
                    SelectSubscriptionPlan(option.apiValue),
                  ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ------------------------------------------------------------------
        // Subscribe button
        // ------------------------------------------------------------------
        if (selected != null)
          LoadingButton(
            label: 'Subscribe to ${_planName(selected)}',
            loading: processing,
            onPressed:
                processing
                    ? null
                    : () => context.read<SubscriptionBloc>().add(
                      const PurchaseSubscription(),
                    ),
            isFilled: true,
          ),
        const SizedBox(height: 12),
        Text(
          'Amounts shown are indicative; the final charge is set by the server.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _onStateChanged(BuildContext context, SubscriptionState state) {
    if (state is SubscriptionPaymentSuccess) {
      _onPaymentSuccess(context, state.status);
    } else if (state is SubscriptionPaymentFailure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } else if (state is SubscriptionPaymentCancelled) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment cancelled')));
    }
  }

  void _onPaymentSuccess(
    BuildContext context,
    SubscriptionStatusResult status,
  ) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Premium activated!'),
        backgroundColor: AppColors.success,
      ),
    );

    // Refresh the global PremiumCubit so every screen (Premium, Profile, AI,
    // etc.) reflects the active Premium state without requiring an app
    // restart. Fire and forget; the PremiumCubit emits states that rebuild the
    // listening screens.
    context.read<PremiumCubit>().load();

    if (!mounted) return;
    context.pop();
  }

  String _planName(String period) {
    switch (period) {
      case 'monthly':
        return 'Monthly Premium';
      case 'yearly':
        return 'Yearly Premium';
      default:
        return period;
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// A selectable plan card.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: selected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              selected ? AppColors.primary : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\u20B9${option.displayPrice}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          option.duration,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppColors.success),
                ],
              ),
              const SizedBox(height: 16),
              ...option.features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(feature, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
