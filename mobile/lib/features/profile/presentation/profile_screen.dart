

import 'dart:ui';

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
  static const bg = Color(0xFF0B1025);
  static const purple = Color(0xFF9B6DFF);
  static const pink = Color(0xFFFF71C6);
  static const blue = Color(0xFF58B7FF);
  static const white = Color(0xFFF6F4FF);
  static const muted = Color(0xFFB9BDD5);

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
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const _ProfileBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR SPACE',
                              style: TextStyle(
                                color: pink,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'My Profile',
                              style: TextStyle(
                                color: white,
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _HeaderButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: () => context.push(AppRoutes.notifications),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: BlocBuilder<ProfileCubit, LoadState<UserProfile>>(
                    builder: (context, state) {
                      return AsyncContent<UserProfile>(
                        value: state,
                        error:
                            (e, st) => _ProfileError(
                              message: '$e',
                              onRetry:
                                  () => context.read<ProfileCubit>().load(),
                            ),
                        data: (user) {
                          final p = user.profile;

                          return RefreshIndicator(
                            color: purple,
                            backgroundColor: const Color(0xFF202541),
                            onRefresh:
                                () => context.read<ProfileCubit>().load(),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                              children: [
                                // Profile hero
                                _GlassCard(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    25,
                                    20,
                                    22,
                                  ),
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
                                                colors: [pink, purple, blue],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: purple.withValues(
                                                    alpha: 0.35,
                                                  ),
                                                  blurRadius: 28,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: const BoxDecoration(
                                                color: bg,
                                                shape: BoxShape.circle,
                                              ),
                                              child: UserAvatar(
                                                url: p.avatar,
                                                name: p.name,
                                                radius: 53,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 21,
                                            height: 21,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF45E6A5),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: bg,
                                                width: 3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 17),
                                      Text(
                                        p.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: white,
                                          fontSize: 27,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _ProfilePill(
                                            icon: Icons.translate_rounded,
                                            label: p.englishLevel.api,
                                            color: purple,
                                          ),
                                          if (p.nativeLanguage.isNotEmpty)
                                            _ProfilePill(
                                              icon: Icons.language_rounded,
                                              label: p.nativeLanguage,
                                              color: blue,
                                            ),
                                          if (p.learningLanguage.isNotEmpty)
                                            _ProfilePill(
                                              icon: Icons.auto_awesome_rounded,
                                              label:
                                                  'Learning ${p.learningLanguage}',
                                              color: pink,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 13,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.045,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.chat_bubble_outline_rounded,
                                              color: purple,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Your learning journey',
                                                    style: TextStyle(
                                                      color: white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    'Keep practising every day',
                                                    style: TextStyle(
                                                      color: muted,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (user.subscriptionPlan ==
                                                SubscriptionPlan.premium)
                                              const _PremiumBadge()
                                            else
                                              _PremiumAction(
                                                onTap:
                                                    () => context.push(
                                                      AppRoutes.premium,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Premium status
                                const SizedBox(height: 23),
                                if (user.subscriptionPlan ==
                                    SubscriptionPlan.premium)
                                  const _SectionHeading(
                                    title: 'Membership',
                                    subtitle: 'Your current plan',
                                    icon: Icons.workspace_premium_rounded,
                                    accent: Color(0xFFFFC76A),
                                  )
                                else
                                  const _SectionHeading(
                                    title: 'Unlock more',
                                    subtitle: 'Get more from PeerUp',
                                    icon: Icons.auto_awesome_rounded,
                                    accent: pink,
                                  ),
                                const SizedBox(height: 12),
                                _GlassCard(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          gradient: AppColors.brandGradient,
                                        ),
                                        child: const Icon(
                                          Icons.workspace_premium_rounded,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.subscriptionPlan ==
                                                      SubscriptionPlan.premium
                                                  ? 'PeerUp Premium'
                                                  : 'Upgrade to Premium',
                                              style: const TextStyle(
                                                color: white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              user.subscriptionPlan ==
                                                      SubscriptionPlan.premium
                                                  ? 'You have a premium plan'
                                                  : 'Explore premium features',
                                              style: const TextStyle(
                                                color: muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed:
                                            () =>
                                                context.push(AppRoutes.premium),
                                        icon: const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: purple,
                                          size: 17,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Bio
                                if (p.bio != null &&
                                    p.bio!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 25),
                                  const _SectionHeading(
                                    title: 'About me',
                                    subtitle: 'A little about who you are',
                                    icon: Icons.person_outline_rounded,
                                    accent: purple,
                                  ),
                                  const SizedBox(height: 12),
                                  _GlassCard(
                                    child: Text(
                                      p.bio!,
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 14,
                                        height: 1.8,
                                      ),
                                    ),
                                  ),
                                ],

                                // Interests
                                if (p.interests.isNotEmpty) ...[
                                  const SizedBox(height: 25),
                                  const _SectionHeading(
                                    title: 'My interests',
                                    subtitle: 'Things you enjoy',
                                    icon: Icons.favorite_rounded,
                                    accent: pink,
                                  ),
                                  const SizedBox(height: 12),
                                  _GlassCard(
                                    child: Wrap(
                                      spacing: 9,
                                      runSpacing: 10,
                                      children: [
                                        for (
                                          int i = 0;
                                          i < p.interests.length;
                                          i++
                                        )
                                          _InterestChip(
                                            label: p.interests[i],
                                            color:
                                                [
                                                  blue,
                                                  pink,
                                                  purple,
                                                  const Color(0xFFFFC76A),
                                                  const Color(0xFF5FE0BD),
                                                ][i % 5],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Conversation goals
                                if (p.conversationGoals.isNotEmpty) ...[
                                  const SizedBox(height: 25),
                                  const _SectionHeading(
                                    title: 'My goals',
                                    subtitle: 'What you want to achieve',
                                    icon: Icons.track_changes_rounded,
                                    accent: blue,
                                  ),
                                  const SizedBox(height: 12),
                                  _GlassCard(
                                    padding: EdgeInsets.zero,
                                    child: Column(
                                      children: [
                                        for (
                                          int i = 0;
                                          i < p.conversationGoals.length;
                                          i++
                                        ) ...[
                                          ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 5,
                                                ),
                                            leading: Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: blue.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: const Icon(
                                                Icons.flag_rounded,
                                                color: blue,
                                              ),
                                            ),
                                            title: Text(
                                              p.conversationGoals[i],
                                              style: const TextStyle(
                                                color: white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (i <
                                              p.conversationGoals.length - 1)
                                            Divider(
                                              height: 1,
                                              indent: 72,
                                              color: Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],

                                // Account actions
                                const SizedBox(height: 28),
                                const Text(
                                  'ACCOUNT',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 13),
                                _AccountAction(
                                  icon: Icons.edit_rounded,
                                  title: 'Edit profile',
                                  subtitle: 'Update your personal details',
                                  accent: purple,
                                  onTap:
                                      () => context.push(AppRoutes.editProfile),
                                ),
                                const SizedBox(height: 10),
                                _AccountAction(
                                  icon: Icons.workspace_premium_rounded,
                                  title: 'Premium & usage',
                                  subtitle: 'Manage your plan',
                                  accent: const Color(0xFFFFC76A),
                                  onTap: () => context.push(AppRoutes.premium),
                                ),
                                const SizedBox(height: 10),
                                _AccountAction(
                                  icon: Icons.settings_rounded,
                                  title: 'Settings',
                                  subtitle: 'Manage your preferences',
                                  accent: blue,
                                  onTap: () => context.push(AppRoutes.settings),
                                ),
                                const SizedBox(height: 20),
                                _GlassCard(
                                  padding: EdgeInsets.zero,
                                  radius: 18,
                                  child: ListTile(
                                    onTap: () async {
                                      await context.read<AuthCubit>().logout();
                                    },
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: const Icon(
                                      Icons.logout_rounded,
                                      color: Color(0xFFFF788D),
                                    ),
                                    title: const Text(
                                      'Log out',
                                      style: TextStyle(
                                        color: Color(0xFFFF788D),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: muted,
                                      size: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Center(
                                  child: Text(
                                    'PEERUP • GROW THROUGH CONVERSATION',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 9,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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
}

// ---------- Background ----------

class _ProfileBackground extends StatelessWidget {
  const _ProfileBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF171331),
                  Color(0xFF0B1025),
                  Color(0xFF101C38),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -100,
          child: _GlowOrb(
            color: const Color(0xFF995EFF).withValues(alpha: 0.24),
          ),
        ),
        Positioned(
          top: 340,
          right: -160,
          child: _GlowOrb(
            color: const Color(0xFFFF60C8).withValues(alpha: 0.13),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -120,
          child: _GlowOrb(
            color: const Color(0xFF39A9FF).withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

// ---------- Reusable glass widgets ----------

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
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.035),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});

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
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white, size: 23),
        ),
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
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
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFFB9BDD5), fontSize: 12),
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
        border: Border.all(color: color.withValues(alpha: 0.4)),
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

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 19,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFB9BDD5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white54,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 15),
          SizedBox(width: 5),
          Text(
            'PRO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumAction extends StatelessWidget {
  const _PremiumAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: 15,
                color: Colors.white,
              ),
              SizedBox(width: 5),
              Text(
                'UPGRADE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: Color(0xFF9B6DFF),
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB9BDD5), fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
