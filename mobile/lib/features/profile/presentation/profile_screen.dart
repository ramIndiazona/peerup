import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/load_state.dart';
import '../../../core/widgets/async_content.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/enums.dart';
import '../../../models/profile.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../bloc/profile_cubit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final cubit = context.read<ProfileCubit>();
      if (!cubit.state.isLoaded && !cubit.state.isLoading) {
        cubit.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(AppRoutes.notifications),
          ),
        ],
      ),
      body: BlocBuilder<ProfileCubit, LoadState<UserProfile>>(
        builder: (context, profile) {
          return AsyncContent<UserProfile>(
            value: profile,
            error:
                (e, st) => _ProfileError(
                  message: '$e',
                  onRetry: () => context.read<ProfileCubit>().load(),
                ),
            data: (user) {
              final p = user.profile;
              return RefreshIndicator(
                onRefresh: () => context.read<ProfileCubit>().load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Center(
                      child: UserAvatar(
                        url: p.avatar,
                        name: p.name,
                        radius: 44,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      p.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.englishLevel.api}  •  ${p.nativeLanguage} → ${p.learningLanguage}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child:
                          user.subscriptionPlan == SubscriptionPlan.premium
                              ? const _BadgePremium()
                              : TextButton.icon(
                                onPressed:
                                    () => context.push(AppRoutes.premium),
                                icon: const Icon(
                                  Icons.workspace_premium_outlined,
                                  size: 18,
                                ),
                                label: const Text('Go Premium'),
                              ),
                    ),
                    if (p.bio != null && p.bio!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(p.bio!, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 24),
                    if (p.interests.isNotEmpty) ...[
                      Text(
                        'Interests',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final i in p.interests) Chip(label: Text(i)),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (p.conversationGoals.isNotEmpty) ...[
                      Text(
                        'Goals',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final g in p.conversationGoals)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.flag_outlined, size: 20),
                          title: Text(g),
                          dense: true,
                        ),
                    ],
                    const SizedBox(height: 20),
                    _ActionListTile(
                      icon: Icons.edit_outlined,
                      title: 'Edit profile',
                      onTap: () => context.push(AppRoutes.editProfile),
                    ),
                    _ActionListTile(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Premium & usage',
                      onTap: () => context.push(AppRoutes.premium),
                    ),
                    _ActionListTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () => context.push(AppRoutes.settings),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        await context.read<AuthCubit>().logout();
                      },
                      child: const Text(
                        'Log out',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BadgePremium extends StatelessWidget {
  const _BadgePremium();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text(
            'PREMIUM',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 44),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ActionListTile extends StatelessWidget {
  const _ActionListTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
