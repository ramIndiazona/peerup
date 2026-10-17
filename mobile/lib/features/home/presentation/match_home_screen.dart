// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:peerup/core/widgets/async_content.dart';
// import 'package:peerup/features/ai/bloc/ai_catalog_cubit.dart';
// import 'package:peerup/features/ai/bloc/ai_session_cubit.dart';
// import 'package:peerup/features/ai/presentation/ai_modes_screen.dart';

// import '../../../core/config/app_routes.dart';
// import '../../../core/theme/app_colors.dart';
// import '../../../core/widgets/user_avatar.dart';
// import '../../../models/enums.dart';
// import '../../../models/live_user.dart';
// import '../../../models/matchmaking.dart';
// import '../../live/cubit/live_cubit.dart';
// import '../../matchmaking/cubit/matchmaking_cubit.dart';
// import '../../profile/bloc/profile_cubit.dart';

// class MatchHomeScreen extends StatefulWidget {
//   const MatchHomeScreen({super.key});

//   @override
//   State<MatchHomeScreen> createState() => _MatchHomeScreenState();
// }

// class _MatchHomeScreenState extends State<MatchHomeScreen> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       final profile = context.read<ProfileCubit>();
//       if (!profile.state.isLoaded && !profile.state.isLoading) {
//         profile.load();
//       }

//       if (!mounted) return;
//       final cubit = context.read<AICatalogCubit>();
//       if (!cubit.state.characters.isLoaded &&
//           !cubit.state.characters.isLoading) {
//         cubit.load();
//       }
//     });
//   }

//   void _startSearch() {
//     final cubit = context.read<MatchmakingCubit>();
//     if (!cubit.state.isSearching) {
//       final profile = context.read<ProfileCubit>().state.valueOrNull;
//       unawaited(cubit.start(MatchFilters.fromProfile(profile)));
//     }
//     context.push(AppRoutes.searching);
//   }

//   Future<void> _start(
//     BuildContext context, {
//     String? characterId,
//     String? scenario,
//   }) async {
//     try {
//       final characters = context.read<AICatalogCubit>().state.characters.value;
//       await context.read<AISessionCubit>().start(
//         characterId: characterId,
//         scenario: scenario,
//         characters: characters ?? const [],
//       );
//       if (!context.mounted) return;
//       context.push(AppRoutes.aiChat);
//     } on Exception catch (e) {
//       if (!context.mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final live = context.watch<LiveCubit>().state;
//     final theme = Theme.of(context);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: PreferredSize(
//         preferredSize: const Size.fromHeight(90),
//         child: Container(
//           color: Colors.white,
//           child: SafeArea(
//             bottom: false,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 24),
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   // Profile
//                   UserAvatar(
//                     url:
//                         context
//                             .watch<ProfileCubit>()
//                             .state
//                             .valueOrNull
//                             ?.profile
//                             .avatar,
//                     name:
//                         context
//                             .watch<ProfileCubit>()
//                             .state
//                             .valueOrNull
//                             ?.profile
//                             .name,
//                     radius: 20,
//                     onTap: () => context.go(AppRoutes.homeProfile),
//                   ),

//                   const SizedBox(width: 16),

//                   // Go Premium
//                   Container(
//                     height: 28,
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFFFFF9DF),
//                       borderRadius: BorderRadius.circular(25),
//                       border: Border.all(
//                         color: const Color(0xFFF1D77A),
//                         width: 1.5,
//                       ),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(
//                           Icons.workspace_premium_outlined,
//                           size: 14,
//                           color: const Color(0xFFE5C55C),
//                         ),
//                         const SizedBox(width: 5),
//                         Text(
//                           'Go Premium',
//                           style: TextStyle(
//                             fontSize: 10,
//                             fontWeight: FontWeight.w600,
//                             color: const Color(0xFFE5C55C),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   const Spacer(),

//                   // Streak
//                   // Row(
//                   //   mainAxisSize: MainAxisSize.min,
//                   //   children: [
//                   //     const Text('🔥', style: TextStyle(fontSize: 32)),
//                   //     const SizedBox(width: 5),
//                   //     const Text(
//                   //       '51',
//                   //       style: TextStyle(
//                   //         fontSize: 29,
//                   //         fontWeight: FontWeight.w500,
//                   //         color: Colors.black,
//                   //       ),
//                   //     ),
//                   //   ],
//                   // ),

//                   // Notification
//                   GestureDetector(
//                     onTap: () {},
//                     child: const Icon(
//                       Icons.notifications_none_rounded,
//                       size: 30,
//                       color: Colors.grey,
//                     ),
//                   ),

//                   const SizedBox(width: 22),

//                   GestureDetector(
//                     onTap: () {},
//                     child: const Icon(
//                       Icons.chat_bubble_outline_rounded,
//                       size: 30,
//                       color: Colors.grey,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//       body: SingleChildScrollView(
//         child: SafeArea(
//           bottom: false,
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 24),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 const SizedBox(height: 12),

//                 const SizedBox(height: 24),
//                 _HeroCard(onStart: _startSearch),

//                 const SizedBox(height: 16),
//                 if (live.others.isNotEmpty) ...[
//                   _LiveList(users: live.others),
//                   const SizedBox(height: 16),
//                 ],

//                 _leaning(),
//                 const SizedBox(height: 16),
//                 Text(
//                   'How it works',
//                   style: theme.textTheme.titleMedium?.copyWith(
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 const _Steps(),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _leaning() {
//     final theme = Theme.of(context);
//     return BlocBuilder<AICatalogCubit, AICatalogState>(
//       builder: (context, state) {
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'PRACTICE WITH AI',
//               style: GoogleFonts.lilitaOne(
//                 fontSize: 27,
//                 fontWeight: FontWeight.w400,
//                 letterSpacing: 1.0,
//                 color: AppColors.primary,
//                 shadows: [
//                   Shadow(
//                     color: AppColors.primary.withValues(alpha: 0.25),
//                     blurRadius: 8,
//                     offset: const Offset(0, 5),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 12),
//             AsyncContent(
//               value: state.characters,
//               data:
//                   (items) => GridView.builder(
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     itemCount: items.length,
//                     gridDelegate:
//                         const SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: 2,
//                           crossAxisSpacing: 12,
//                           mainAxisSpacing: 16,
//                           childAspectRatio: 0.80,
//                         ),
//                     itemBuilder: (context, index) {
//                       final c = items[index];

//                       return CharacterCard(
//                         character: c,
//                         onTap: () => _start(context, characterId: c.id),
//                       );
//                     },
//                   ),
//             ),
//             const SizedBox(height: 24),
//           ],
//         );
//       },
//     );
//   }
// }

// class _LiveList extends StatelessWidget {
//   const _LiveList({required this.users});

//   final List<LiveUser> users;

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 10),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 14),
//               child: Text(
//                 'Live now',
//                 style: theme.textTheme.titleSmall?.copyWith(
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 6),
//             for (final user in users.take(4))
//               Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 10,
//                   vertical: 4,
//                 ),
//                 child: Row(
//                   children: [
//                     UserAvatar(url: user.avatar, name: user.name, radius: 18),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             user.name,
//                             style: theme.textTheme.bodyMedium?.copyWith(
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           Text(
//                             '${user.englishLevel.api} · ${user.nativeLanguage}',
//                             style: theme.textTheme.bodySmall?.copyWith(
//                               color: theme.colorScheme.outline,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 3,
//                       ),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
//                         borderRadius: BorderRadius.circular(999),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           const Icon(
//                             Icons.circle,
//                             size: 8,
//                             color: Color(0xFF2E7D32),
//                           ),
//                           const SizedBox(width: 4),
//                           Text(
//                             user.status == UserStatus.searching
//                                 ? 'searching'
//                                 : 'live',
//                             style: theme.textTheme.labelSmall?.copyWith(
//                               color: const Color(0xFF2E7D32),
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _HeroCard extends StatefulWidget {
//   const _HeroCard({required this.onStart});

//   final VoidCallback onStart;

//   @override
//   State<_HeroCard> createState() => _HeroCardState();
// }

// class _HeroCardState extends State<_HeroCard>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _waveController;

//   @override
//   void initState() {
//     super.initState();

//     _waveController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _waveController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         image: const DecorationImage(
//           image: AssetImage('assets/home.png'),
//           fit: BoxFit.fill,
//         ),
//         borderRadius: BorderRadius.circular(24),
//       ),
//       child: Column(
//         children: [
//           const SizedBox(height: 210),
//           Transform.translate(
//             offset: const Offset(0, 28),
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 50),
//               child: SizedBox(
//                 width: double.infinity,
//                 height: 40,
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(5),
//                   child: Stack(
//                     children: [
//                       Container(
//                         width: double.infinity,
//                         height: 52,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(5),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withValues(alpha: 0.25),
//                               blurRadius: 12,
//                               offset: const Offset(0, 6),
//                             ),
//                           ],
//                         ),
//                       ),

//                       Positioned.fill(
//                         child: IgnorePointer(
//                           child: AnimatedBuilder(
//                             animation: _waveController,
//                             builder: (context, child) {
//                               final value = _waveController.value;

//                               return Align(
//                                 alignment: Alignment(-1.5 + (value * 3.0), 0),
//                                 child: Container(
//                                   width: 100,
//                                   height: 80,
//                                   decoration: BoxDecoration(
//                                     gradient: LinearGradient(
//                                       begin: Alignment.centerLeft,
//                                       end: Alignment.centerRight,
//                                       colors: [
//                                         Colors.transparent,
//                                         AppColors.primary.withValues(
//                                           alpha: 0.08,
//                                         ),
//                                         AppColors.primary.withValues(
//                                           alpha: 0.25,
//                                         ),
//                                         Colors.white.withValues(alpha: 0.6),
//                                         AppColors.primary.withValues(
//                                           alpha: 0.15,
//                                         ),
//                                         Colors.transparent,
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                         ),
//                       ),

//                       Material(
//                         color: Colors.transparent,
//                         child: InkWell(
//                           onTap: widget.onStart,
//                           borderRadius: BorderRadius.circular(18),
//                           child: Center(
//                             child: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Icon(
//                                   Icons.call,
//                                   color: AppColors.primary,
//                                   size: 22,
//                                 ),

//                                 const SizedBox(width: 8),

//                                 Text(
//                                   'Start conversation',
//                                   style: TextStyle(
//                                     color: AppColors.primary,
//                                     fontSize: 18,
//                                     fontWeight: FontWeight.w700,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),

//           const SizedBox(height: 65),
//         ],
//       ),
//     );
//   }
// }

// class _Steps extends StatelessWidget {
//   const _Steps();

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final items = [
//       (
//         icon: Icons.search_rounded,
//         title: 'We match you',
//         subtitle: 'By level, interests and goals',
//       ),
//       (
//         icon: Icons.call_rounded,
//         title: 'You talk',
//         subtitle: 'Voice calls with a live partner',
//       ),
//       (
//         icon: Icons.insights_rounded,
//         title: 'You improve',
//         subtitle: 'Learn from real conversation',
//       ),
//     ];
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             for (final item in items)
//               Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 10),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 40,
//                       height: 40,
//                       decoration: BoxDecoration(
//                         color: theme.colorScheme.primary.withValues(
//                           alpha: 0.12,
//                         ),
//                         shape: BoxShape.circle,
//                       ),
//                       child: Icon(
//                         item.icon,
//                         color: theme.colorScheme.primary,
//                         size: 20,
//                       ),
//                     ),
//                     const SizedBox(width: 14),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             item.title,
//                             style: const TextStyle(fontWeight: FontWeight.w700),
//                           ),
//                           Text(
//                             item.subtitle,
//                             style: theme.textTheme.bodySmall?.copyWith(
//                               color: theme.colorScheme.outline,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:peerup/core/widgets/async_content.dart';

import 'package:peerup/features/ai/bloc/ai_catalog_cubit.dart';

import 'package:peerup/features/ai/bloc/ai_session_cubit.dart';

import 'package:peerup/features/ai/presentation/ai_modes_screen.dart';

import '../../../core/config/app_routes.dart';

import '../../../core/theme/app_colors.dart';

import '../../../core/widgets/unread_badge.dart';

import '../../../core/widgets/user_avatar.dart';

import '../../../models/enums.dart';

import '../../../models/live_user.dart';

import '../../../models/matchmaking.dart';

import '../../live/cubit/live_cubit.dart';

import '../../matchmaking/cubit/matchmaking_cubit.dart';

import '../../notifications/bloc/notifications_cubit.dart';

import '../../profile/bloc/profile_cubit.dart';

class MatchHomeScreen extends StatefulWidget {
  const MatchHomeScreen({super.key});

  @override
  State<MatchHomeScreen> createState() => _MatchHomeScreenState();
}

class _MatchHomeScreenState extends State<MatchHomeScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final profile = context.read<ProfileCubit>();

      if (!profile.state.isLoaded && !profile.state.isLoading) {
        profile.load();
      }

      if (!mounted) return;

      final cubit = context.read<AICatalogCubit>();

      if (!cubit.state.characters.isLoaded &&
          !cubit.state.characters.isLoading) {
        cubit.load();
      }

      if (!mounted) return;

      // Populate the notification badge on the home AppBar.
      final notifications = context.read<NotificationsCubit>();

      if (notifications.state.isInitial) {
        notifications.load();
      }
    });
  }

  void _startSearch() {
    final cubit = context.read<MatchmakingCubit>();

    if (!cubit.state.isSearching) {
      final profile = context.read<ProfileCubit>().state.valueOrNull;

      unawaited(cubit.start(MatchFilters.fromProfile(profile)));
    }

    context.push(AppRoutes.searching);
  }

  Future<void> _start(
    BuildContext context, {

    String? characterId,

    String? scenario,
  }) async {
    try {
      final characters = context.read<AICatalogCubit>().state.characters.value;

      await context.read<AISessionCubit>().start(
        characterId: characterId,

        scenario: scenario,

        characters: characters ?? const [],
      );

      if (!context.mounted) return;

      context.push(AppRoutes.aiChat);
    } on Exception catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveCubit>().state;

    final theme = Theme.of(context).copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B1020),
      colorScheme: Theme.of(context).colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: const Color(0xFF9B8CFF),
        surface: const Color(0xFF151B30),
      ),
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: const Color(0xFFF5F6FF),
        displayColor: const Color(0xFFF5F6FF),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1020),

        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(90),

          child: Container(
            color: const Color(0xFF0B1020),

            child: SafeArea(
              bottom: false,

              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,

                  children: [
                    // Profile
                    UserAvatar(
                      url:
                          context
                              .watch<ProfileCubit>()
                              .state
                              .valueOrNull
                              ?.profile
                              .avatar,

                      name:
                          context
                              .watch<ProfileCubit>()
                              .state
                              .valueOrNull
                              ?.profile
                              .name,

                      radius: 20,

                      onTap: () => context.go(AppRoutes.homeProfile),
                    ),

                    const SizedBox(width: 16),

                    // Go Premium
                    Container(
                      height: 28,

                      padding: const EdgeInsets.symmetric(horizontal: 16),

                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD28B).withValues(alpha: 0.10),

                        borderRadius: BorderRadius.circular(25),

                        border: Border.all(
                          color: const Color(
                            0xFFFFD28B,
                          ).withValues(alpha: 0.30),

                          width: 1.5,
                        ),
                      ),

                      child: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          Icon(
                            Icons.workspace_premium_outlined,

                            size: 14,

                            color: const Color(0xFFFFD28B),
                          ),

                          const SizedBox(width: 5),

                          Text(
                            'Go Premium',

                            style: TextStyle(
                              fontSize: 10,

                              fontWeight: FontWeight.w600,

                              color: const Color(0xFFFFD28B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Streak

                    // Row(

                    //   mainAxisSize: MainAxisSize.min,

                    //   children: [

                    //     const Text('🔥', style: TextStyle(fontSize: 32)),

                    //     const SizedBox(width: 5),

                    //     const Text(

                    //       '51',

                    //       style: TextStyle(

                    //         fontSize: 29,

                    //         fontWeight: FontWeight.w500,

                    //         color: Colors.black,

                    //       ),

                    //     ),

                    //   ],

                    // ),

                    // Notification
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.notifications),

                      child:
                          BlocBuilder<NotificationsCubit, NotificationsState>(
                            buildWhen:
                                (previous, current) =>
                                    previous.unreadCount != current.unreadCount,

                            builder:
                                (context, state) => UnreadBadge(
                                  count: state.unreadCount,

                                  child: const Icon(
                                    Icons.notifications_none_rounded,

                                    size: 30,

                                    color: Color(0xFF9AA5C4),
                                  ),
                                ),
                          ),
                    ),

                    const SizedBox(width: 22),

                    GestureDetector(
                      onTap: () => context.push(AppRoutes.friends),

                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,

                        size: 30,

                        color: Color(0xFF9AA5C4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        body: SingleChildScrollView(
          child: SafeArea(
            bottom: false,

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [
                  const SizedBox(height: 12),

                  const SizedBox(height: 24),

                  _HeroCard(onStart: _startSearch),

                  const SizedBox(height: 16),

                  if (live.others.isNotEmpty) ...[
                    _LiveList(users: live.others),

                    const SizedBox(height: 16),
                  ],

                  _leaning(),

                  const SizedBox(height: 16),

                  Text(
                    'How it works',

                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const _Steps(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leaning() {
    final theme = Theme.of(context);

    return BlocBuilder<AICatalogCubit, AICatalogState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              'PRACTICE WITH AI',

              style: GoogleFonts.lilitaOne(
                fontSize: 27,

                fontWeight: FontWeight.w400,

                letterSpacing: 1.0,

                color: AppColors.primary,

                shadows: [
                  Shadow(
                    color: AppColors.primary.withValues(alpha: 0.25),

                    blurRadius: 8,

                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            AsyncContent(
              value: state.characters,

              data:
                  (items) => GridView.builder(
                    shrinkWrap: true,

                    physics: const NeverScrollableScrollPhysics(),

                    itemCount: items.length,

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,

                          crossAxisSpacing: 12,

                          mainAxisSpacing: 16,

                          childAspectRatio: 0.80,
                        ),

                    itemBuilder: (context, index) {
                      final c = items[index];

                      return CharacterCard(
                        character: c,

                        onTap: () => _start(context, characterId: c.id),
                      );
                    },
                  ),
            ),

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _LiveList extends StatelessWidget {
  const _LiveList({required this.users});

  final List<LiveUser> users;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),

              child: Text(
                'Live now',

                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 6),

            for (final user in users.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,

                  vertical: 4,
                ),

                child: Row(
                  children: [
                    UserAvatar(url: user.avatar, name: user.name, radius: 18),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            user.name,

                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          Text(
                            '${user.englishLevel.api} · ${user.nativeLanguage}',

                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,

                        vertical: 3,
                      ),

                      decoration: BoxDecoration(
                        color: const Color(0xFF49D9A0).withValues(alpha: 0.12),

                        borderRadius: BorderRadius.circular(999),
                      ),

                      child: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          const Icon(
                            Icons.circle,

                            size: 8,

                            color: Color(0xFF2E7D32),
                          ),

                          const SizedBox(width: 4),

                          Text(
                            user.status == UserStatus.searching
                                ? 'searching'
                                : 'live',

                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF49D9A0),

                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.onStart});

  final VoidCallback onStart;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,

      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/home.png'),

          fit: BoxFit.fill,
        ),

        borderRadius: BorderRadius.circular(24),
      ),

      child: Column(
        children: [
          const SizedBox(height: 210),

          Transform.translate(
            offset: const Offset(0, 28),

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),

              child: SizedBox(
                width: double.infinity,

                height: 40,

                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),

                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,

                        height: 52,

                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1020),

                          borderRadius: BorderRadius.circular(5),

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),

                              blurRadius: 12,

                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),

                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _waveController,

                            builder: (context, child) {
                              final value = _waveController.value;

                              return Align(
                                alignment: Alignment(-1.5 + (value * 3.0), 0),

                                child: Container(
                                  width: 100,

                                  height: 80,

                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,

                                      end: Alignment.centerRight,

                                      colors: [
                                        Colors.transparent,

                                        AppColors.primary.withValues(
                                          alpha: 0.08,
                                        ),

                                        AppColors.primary.withValues(
                                          alpha: 0.25,
                                        ),

                                        Colors.white.withValues(alpha: 0.6),

                                        AppColors.primary.withValues(
                                          alpha: 0.15,
                                        ),

                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      Material(
                        color: Colors.transparent,

                        child: InkWell(
                          onTap: widget.onStart,

                          borderRadius: BorderRadius.circular(18),

                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,

                              children: [
                                Icon(
                                  Icons.call,

                                  color: AppColors.primary,

                                  size: 22,
                                ),

                                const SizedBox(width: 8),

                                Text(
                                  'Start conversation',

                                  style: TextStyle(
                                    color: AppColors.primary,

                                    fontSize: 18,

                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 65),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final items = [
      (
        icon: Icons.search_rounded,

        title: 'We match you',

        subtitle: 'By level, interests and goals',
      ),

      (
        icon: Icons.call_rounded,

        title: 'You talk',

        subtitle: 'Voice calls with a live partner',
      ),

      (
        icon: Icons.insights_rounded,

        title: 'You improve',

        subtitle: 'Learn from real conversation',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),

                child: Row(
                  children: [
                    Container(
                      width: 40,

                      height: 40,

                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),

                        shape: BoxShape.circle,
                      ),

                      child: Icon(
                        item.icon,

                        color: theme.colorScheme.primary,

                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            item.title,

                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),

                          Text(
                            item.subtitle,

                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
