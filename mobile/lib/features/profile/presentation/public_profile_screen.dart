

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:peerup/core/theme/app_colors.dart';

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

  static const _background = Color(0xFF0B1025);
  static const _purple = Color(0xFF9B6DFF);
  static const _pink = Color(0xFFFF71C6);
  static const _blue = Color(0xFF58B7FF);
  static const _text = Color(0xFFF6F4FF);
  static const _muted = Color(0xFFB9BDD5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          const Positioned.fill(child: _GradientBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Expanded(
                        child: Text(
                          'PROFILE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      BlocBuilder<PublicProfileCubit, LoadState<PublicProfile>>(
                        builder: (context, state) {
                          return AsyncContent<PublicProfile>(
                            value: state,
                            error: (e, st) => _Unavailable(message: '$e'),
                            data: (p) => _buildProfile(context, p),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(BuildContext context, PublicProfile p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        // Hero profile card
        _GlassCard(
          radius: 30,
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_pink, _purple, _blue],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _purple.withValues(alpha: 0.4),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _background,
                      ),
                      child: UserAvatar(
                        url: p.avatar,
                        name: p.name,
                        radius: 53,
                      ),
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF45E6A5),
                      shape: BoxShape.circle,
                      border: Border.all(color: _background, width: 3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                p.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    icon: Icons.translate_rounded,
                    text: p.englishLevel.api,
                    color: _purple,
                  ),
                  if (p.country != null && p.country!.isNotEmpty)
                    _Pill(
                      icon: Icons.location_on_outlined,
                      text: p.country!,
                      color: _pink,
                    ),
                  if (p.yearsOld != null)
                    _Pill(
                      icon: Icons.cake_outlined,
                      text: '${p.yearsOld} years',
                      color: _blue,
                    ),
                ],
              ),
              if (p.nativeLanguage.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.language_rounded, color: _blue, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Native language: ${p.nativeLanguage}',
                        style: const TextStyle(color: _muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        if (p.bio != null && p.bio!.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'About me',
            subtitle: 'A little introduction',
            icon: Icons.auto_awesome_rounded,
            accent: _purple,
          ),
          const SizedBox(height: 12),
          _GlassCard(
            child: Text(
              p.bio!,
              style: const TextStyle(color: _muted, fontSize: 15, height: 1.8),
            ),
          ),
        ],

        if (p.interests.isNotEmpty) ...[
          const SizedBox(height: 26),
          const _SectionTitle(
            title: 'Interests',
            subtitle: 'Things I enjoy',
            icon: Icons.favorite_rounded,
            accent: _pink,
          ),
          const SizedBox(height: 14),
          _GlassCard(
            child: Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                for (int i = 0; i < p.interests.length; i++)
                  _InterestChip(
                    label: p.interests[i],
                    color:
                        [
                          _blue,
                          _pink,
                          _purple,
                          const Color(0xFFFFBE6B),
                          const Color(0xFF5FE0BD),
                        ][i % 5],
                  ),
              ],
            ),
          ),
        ],

        if (p.conversationGoals.isNotEmpty) ...[
          const SizedBox(height: 26),
          const _SectionTitle(
            title: 'Conversation goals',
            subtitle: 'What I want to achieve',
            icon: Icons.track_changes_rounded,
            accent: _blue,
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < p.conversationGoals.length; i++) ...[
            _GlassCard(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        colors: [
                          [_purple, _blue, _pink, const Color(0xFF5FE0BD)][i %
                              4].withValues(alpha: 0.35),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Icon(
                      [
                        Icons.record_voice_over_rounded,
                        Icons.public_rounded,
                        Icons.people_alt_rounded,
                        Icons.trending_up_rounded,
                      ][i % 4],
                      color:
                          [_purple, _blue, _pink, const Color(0xFF5FE0BD)][i %
                              4],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      p.conversationGoals[i],
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white38,
                    size: 15,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],

        const SizedBox(height: 24),
        const Text(
          'SAFETY & PRIVACY',
          style: TextStyle(
            color: _muted,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SafetyButton(
                label: 'Block user',
                icon: Icons.block_rounded,
                color: const Color(0xFFFF788D),
                onTap: () => _blockUser(context, p),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SafetyButton(
                label: 'Report user',
                icon: Icons.flag_outlined,
                color: _blue,
                onTap: () => _reportDialog(context, p),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _blockUser(BuildContext context, PublicProfile p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF202541),
            title: const Text(
              'Block this user?',
              style: TextStyle(color: _text),
            ),
            content: Text(
              'You may no longer be able to interact with ${p.name}.',
              style: const TextStyle(color: _muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Block'),
              ),
            ],
          ),
    );

    if (confirmed != true || !context.mounted) return;

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
      backgroundColor: const Color(0xFF171C36),
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Report ${p.name}',
                    style: const TextStyle(
                      color: _text,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select the reason that best describes the issue.',
                    style: TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 16),
                  for (final r in ReportReason.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.flag_outlined, color: _pink),
                      title: Text(
                        r.label,
                        style: const TextStyle(color: _text),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _muted,
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(r),
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

// ---------- Background ----------

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF171331),
                Color(0xFF0B1025),
                Color(0xFF111C38),
                Color(0xFF101020),
              ],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          top: -100,
          left: -100,
          child: _GlowOrb(
            color: const Color(0xFF995EFF).withValues(alpha: 0.28),
            size: 270,
          ),
        ),
        Positioned(
          top: 280,
          right: -130,
          child: _GlowOrb(
            color: const Color(0xFFFF60C8).withValues(alpha: 0.16),
            size: 280,
          ),
        ),
        Positioned(
          bottom: -150,
          left: -90,
          child: _GlowOrb(
            color: const Color(0xFF39A9FF).withValues(alpha: 0.18),
            size: 300,
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

// ---------- Glass components ----------

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.105),
                Colors.white.withValues(alpha: 0.035),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.text, size: 19),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: accent, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SafetyButton extends StatelessWidget {
  const _SafetyButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 17,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
            child: Column(
              children: [
                Icon(icon, color: color, size: 23),
                const SizedBox(height: 7),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: _GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off_rounded,
                color: AppColors.purple,
                size: 48,
              ),
              const SizedBox(height: 14),
              const Text(
                'Profile unavailable',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
