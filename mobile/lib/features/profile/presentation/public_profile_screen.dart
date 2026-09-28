import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/load_state.dart';
import '../../../core/widgets/async_content.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/enums.dart';
import '../../../models/profile.dart';
import '../bloc/public_profile_cubit.dart';
import '../profile_repository.dart';

class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: BlocBuilder<PublicProfileCubit, LoadState<PublicProfile>>(
        builder: (context, state) {
          return AsyncContent<PublicProfile>(
            value: state,
            error: (e, st) => _BlockedOrMissingView(message: '$e'),
            data: (p) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: UserAvatar(url: p.avatar, name: p.name, radius: 48),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    p.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      p.englishLevel.api,
                      if (p.nativeLanguage.isNotEmpty)
                        'speaks ${p.nativeLanguage}',
                      if (p.country != null && p.country!.isNotEmpty)
                        'from ${p.country}',
                      if (p.yearsOld != null) '${p.yearsOld}',
                    ].join('  •  '),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  if (p.bio != null && p.bio!.isNotEmpty) ...[
                    const SizedBox(height: 16),
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
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _blockUser(context, p),
                          icon: const Icon(Icons.block_rounded),
                          label: const Text('Block'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _reportDialog(context, p),
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('Report'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _blockUser(BuildContext context, PublicProfile p) async {
    try {
      await context.read<ProfileRepository>().blockUser(p.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User blocked')));
      Navigator.of(context).pop();
    } on Exception catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _reportDialog(BuildContext context, PublicProfile p) async {
    final reason = await showModalBottomSheet<ReportReason>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Why are you reporting ${p.name}?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in ReportReason.values)
                        ActionChip(
                          label: Text(r.label),
                          onPressed: () => Navigator.of(context).pop(r),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
    if (reason == null || !context.mounted) return;
    try {
      await context.read<ProfileRepository>().reportUser(
        p.id,
        reason: reason.api,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted')));
    } on Exception catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}

class _BlockedOrMissingView extends StatelessWidget {
  const _BlockedOrMissingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_off_rounded, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
