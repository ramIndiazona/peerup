// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:peerup/features/tongue/bloc/tongue_twister_bloc.dart';
// import 'package:peerup/features/tongue/bloc/tongue_twister_event.dart';
// import 'package:peerup/features/tongue/bloc/tongue_twister_state.dart';
// import 'package:peerup/models/tongue_twister.dart';

// import 'TongueTwisterDetailPage.dart';

// class TongueTwisterPracticePage extends StatefulWidget {
//   const TongueTwisterPracticePage({super.key});

//   @override
//   State<TongueTwisterPracticePage> createState() =>
//       _TongueTwisterPracticePageState();
// }

// class _TongueTwisterPracticePageState extends State<TongueTwisterPracticePage> {
//   static const Color primary = Color(0xFF625FE8);
//   static const Color background = Color(0xFFF7F7FC);

//   int _selectedCategory = 0;

//   final List<String> _categories = ['For You', 'Beginner', 'Medium', 'Hard'];

//   // Convert API color strings such as "#E9E7FF" into Flutter Colors.
//   Color _parseColor(String? value) {
//     if (value == null || value.trim().isEmpty) {
//       return const Color(0xFFE9E7FF);
//     }

//     String hex = value.trim().replaceAll('#', '');

//     if (hex.length == 6) {
//       hex = 'FF$hex';
//     }

//     if (hex.length == 8) {
//       final parsed = int.tryParse(hex, radix: 16);
//       if (parsed != null) return Color(parsed);
//     }

//     return const Color(0xFFE9E7FF);
//   }

//   IconData _parseIcon(String? value) {
//     switch (value?.toLowerCase()) {
//       case 'coffee':
//       case 'coffee_rounded':
//         return Icons.coffee_rounded;

//       case 'local_fire_department':
//       case 'local_fire_department_rounded':
//         return Icons.local_fire_department_rounded;

//       case 'waves':
//       case 'waves_rounded':
//         return Icons.waves_rounded;

//       case 'spa':
//       case 'spa_rounded':
//         return Icons.spa_rounded;

//       case 'bakery_dining':
//       case 'bakery_dining_rounded':
//         return Icons.bakery_dining_rounded;

//       case 'location_city':
//       case 'location_city_rounded':
//         return Icons.location_city_rounded;

//       case 'set_meal':
//       case 'set_meal_rounded':
//         return Icons.set_meal_rounded;

//       case 'pets':
//       case 'pets_rounded':
//         return Icons.pets_rounded;

//       case 'visibility':
//       case 'visibility_rounded':
//         return Icons.visibility_rounded;

//       case 'bug_report':
//       case 'bug_report_rounded':
//         return Icons.bug_report_rounded;

//       case 'kitchen':
//       case 'kitchen_rounded':
//         return Icons.kitchen_rounded;

//       case 'water':
//       case 'water_rounded':
//         return Icons.water_rounded;

//       case 'checkroom':
//       case 'checkroom_rounded':
//         return Icons.checkroom_rounded;

//       case 'landscape':
//       case 'landscape_rounded':
//         return Icons.landscape_rounded;

//       case 'toys':
//       case 'toys_rounded':
//         return Icons.toys_rounded;

//       case 'storefront':
//       case 'storefront_rounded':
//         return Icons.storefront_rounded;

//       case 'military_tech':
//       case 'military_tech_rounded':
//         return Icons.military_tech_rounded;

//       case 'grass':
//       case 'grass_rounded':
//         return Icons.grass_rounded;

//       case 'forest':
//       case 'forest_rounded':
//         return Icons.forest_rounded;

//       case 'access_time':
//       case 'access_time_rounded':
//         return Icons.access_time_rounded;

//       case 'record_voice_over':
//       case 'record_voice_over_rounded':
//       default:
//         return Icons.record_voice_over_rounded;
//     }
//   }

//   List<Map<String, dynamic>> _mapTwisters(List<TongueTwister> twisters) {
//     return twisters.map((twister) {
//       return <String, dynamic>{
//         'id': twister.id,
//         'title': twister.title,
//         'text': twister.text,
//         'level': twister.level,
//         'seconds': '${twister.seconds} sec',
//         'xp': twister.xp,
//         'color': _parseColor(twister.color),
//         'icon': _parseIcon(twister.icon),
//       };
//     }).toList();
//   }

//   List<Map<String, dynamic>> _filteredTwisters(
//     List<Map<String, dynamic>> twisters,
//   ) {
//     if (_selectedCategory == 0) {
//       return twisters;
//     }

//     final selectedLevel = _categories[_selectedCategory];

//     return twisters.where((item) => item['level'] == selectedLevel).toList();
//   }

//   void _openPractice(Map<String, dynamic> item) {
//     Navigator.of(context).push(
//       PageRouteBuilder<void>(
//         transitionDuration: Duration.zero,
//         reverseTransitionDuration: Duration.zero,
//         pageBuilder: (_, __, ___) => TongueTwisterDetailPage(item: item),
//         transitionsBuilder: (_, __, ___, child) => child,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<TongueTwisterBloc, TongueTwisterState>(
//       builder: (context, state) {
//         print('TongueTwisterPracticePage: Current state: $state');
//         if (state is TongueTwisterInitial || state is TongueTwisterLoading) {
//           return const Scaffold(
//             backgroundColor: background,
//             body: Center(child: CircularProgressIndicator(color: primary)),
//           );
//         }

//         if (state is TongueTwisterError) {
//           return Scaffold(
//             backgroundColor: background,
//             body: SafeArea(
//               child: Center(
//                 child: Padding(
//                   padding: const EdgeInsets.all(24),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       const Icon(
//                         Icons.error_outline_rounded,
//                         size: 52,
//                         color: Colors.redAccent,
//                       ),
//                       const SizedBox(height: 16),
//                       const Text(
//                         'Unable to load challenges',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontSize: 19,
//                           fontWeight: FontWeight.w800,
//                           color: Color(0xFF24243B),
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         state.message,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           fontSize: 13,
//                           color: Color(0xFF85859B),
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       ElevatedButton.icon(
//                         onPressed: () {
//                           context.read<TongueTwisterBloc>().add(
//                             FetchTongueTwisters(),
//                           );
//                         },
//                         icon: const Icon(Icons.refresh_rounded),
//                         label: const Text('Try again'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: primary,
//                           foregroundColor: Colors.white,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           );
//         }

//         if (state is TongueTwisterLoaded) {
//           final allItems = _mapTwisters(state.twisters);
//           final items = _filteredTwisters(allItems);

//           return Scaffold(
//             backgroundColor: background,
//             body: SafeArea(
//               child: Column(
//                 children: [
//                   // Header
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
//                     child: Row(
//                       children: [
//                         Container(
//                           height: 54,
//                           width: 54,
//                           decoration: BoxDecoration(
//                             gradient: const LinearGradient(
//                               colors: [Color(0xFF7773F1), Color(0xFF625FE8)],
//                             ),
//                             borderRadius: BorderRadius.circular(18),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: primary.withValues(alpha: 0.20),
//                                 blurRadius: 18,
//                                 offset: const Offset(0, 7),
//                               ),
//                             ],
//                           ),
//                           child: const Icon(
//                             Icons.record_voice_over_rounded,
//                             color: Colors.white,
//                             size: 28,
//                           ),
//                         ),
//                         const SizedBox(width: 14),
//                         const Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'Speaking Practice',
//                                 style: TextStyle(
//                                   fontSize: 23,
//                                   fontWeight: FontWeight.w800,
//                                   color: Color(0xFF24243B),
//                                 ),
//                               ),
//                               SizedBox(height: 4),
//                               Text(
//                                 'Choose a challenge and start practising',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Color(0xFF85859B),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   // Category filters
//                   SizedBox(
//                     height: 46,
//                     child: ListView.separated(
//                       padding: const EdgeInsets.symmetric(horizontal: 22),
//                       scrollDirection: Axis.horizontal,
//                       itemCount: _categories.length,
//                       separatorBuilder: (_, __) => const SizedBox(width: 9),
//                       itemBuilder: (context, index) {
//                         final selected = _selectedCategory == index;

//                         return ChoiceChip(
//                           label: Text(_categories[index]),
//                           selected: selected,
//                           onSelected: (_) {
//                             setState(() {
//                               _selectedCategory = index;
//                             });
//                           },
//                           backgroundColor: Colors.white,
//                           selectedColor: primary,
//                           side: BorderSide(
//                             color: selected ? primary : const Color(0xFFE9E7F4),
//                           ),
//                           labelStyle: TextStyle(
//                             color: selected ? Colors.white : primary,
//                             fontSize: 12,
//                             fontWeight: FontWeight.w700,
//                           ),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(16),
//                           ),
//                           showCheckmark: false,
//                         );
//                       },
//                     ),
//                   ),

//                   const SizedBox(height: 22),

//                   // List heading
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 22),
//                     child: Row(
//                       children: [
//                         const Expanded(
//                           child: Text(
//                             'Choose your challenge',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.w800,
//                               color: Color(0xFF24243B),
//                             ),
//                           ),
//                         ),
//                         Text(
//                           '${items.length} challenges',
//                           style: const TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.w600,
//                             color: Color(0xFF85859B),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   const SizedBox(height: 12),

//                   // API data list
//                   Expanded(
//                     child:
//                         items.isEmpty
//                             ? const Center(
//                               child: Text(
//                                 'No challenges found',
//                                 style: TextStyle(
//                                   color: Color(0xFF85859B),
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             )
//                             : RefreshIndicator(
//                               color: primary,
//                               onRefresh: () async {
//                                 context.read<TongueTwisterBloc>().add(
//                                   FetchTongueTwisters(),
//                                 );

//                                 await context
//                                     .read<TongueTwisterBloc>()
//                                     .stream
//                                     .firstWhere(
//                                       (newState) =>
//                                           newState is TongueTwisterLoaded ||
//                                           newState is TongueTwisterError,
//                                     );
//                               },
//                               child: ListView.separated(
//                                 padding: const EdgeInsets.fromLTRB(
//                                   22,
//                                   4,
//                                   22,
//                                   24,
//                                 ),
//                                 physics: const AlwaysScrollableScrollPhysics(),
//                                 itemCount: items.length,
//                                 separatorBuilder:
//                                     (_, __) => const SizedBox(height: 13),
//                                 itemBuilder: (context, index) {
//                                   final item = items[index];

//                                   return _TwisterListCard(
//                                     number: index + 1,
//                                     item: item,
//                                     onTap: () => _openPractice(item),
//                                   );
//                                 },
//                               ),
//                             ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }

//         return const Scaffold(
//           backgroundColor: background,
//           body: Center(child: Text('Something went wrong.')),
//         );
//       },
//     );
//   }
// }

// class _TwisterListCard extends StatelessWidget {
//   const _TwisterListCard({
//     required this.number,
//     required this.item,
//     required this.onTap,
//   });

//   final int number;
//   final Map<String, dynamic> item;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     final Color itemColor = item['color'] as Color? ?? const Color(0xFFE9E7FF);

//     final IconData itemIcon =
//         item['icon'] as IconData? ?? Icons.record_voice_over_rounded;

//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(24),
//         child: Ink(
//           padding: const EdgeInsets.all(17),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [Colors.white, itemColor.withValues(alpha: 0.35)],
//             ),
//             borderRadius: BorderRadius.circular(24),
//             border: Border.all(color: Colors.white, width: 1.5),
//             boxShadow: [
//               BoxShadow(
//                 color: const Color(0xFF625FE8).withValues(alpha: 0.055),
//                 blurRadius: 18,
//                 offset: const Offset(0, 7),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               Container(
//                 height: 55,
//                 width: 55,
//                 decoration: BoxDecoration(
//                   color: itemColor,
//                   borderRadius: BorderRadius.circular(18),
//                 ),
//                 child: Icon(itemIcon, color: const Color(0xFF625FE8), size: 27),
//               ),
//               const SizedBox(width: 14),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'LIST $number',
//                       style: const TextStyle(
//                         color: Color(0xFF85859B),
//                         fontSize: 10,
//                         letterSpacing: 1.1,
//                         fontWeight: FontWeight.w800,
//                       ),
//                     ),
//                     const SizedBox(height: 5),
//                     Text(
//                       item['title']?.toString() ?? 'Tongue Twister',
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 15,
//                         height: 1.3,
//                         fontWeight: FontWeight.w800,
//                         color: Color(0xFF24243B),
//                       ),
//                     ),
//                     const SizedBox(height: 9),
//                     Wrap(
//                       spacing: 7,
//                       runSpacing: 5,
//                       children: [
//                         _SmallTag(
//                           label: item['level']?.toString() ?? 'Beginner',
//                         ),
//                         _SmallTag(
//                           label: item['seconds']?.toString() ?? '60 sec',
//                         ),
//                         _SmallTag(label: '+${item['xp'] ?? 10} XP'),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 8),
//               const Icon(
//                 Icons.arrow_forward_ios_rounded,
//                 size: 17,
//                 color: Color(0xFF625FE8),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _SmallTag extends StatelessWidget {
//   const _SmallTag({required this.label});

//   final String label;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//       decoration: BoxDecoration(
//         color: Colors.white.withValues(alpha: 0.8),
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Text(
//         label,
//         style: const TextStyle(
//           fontSize: 10,
//           fontWeight: FontWeight.w700,
//           color: Color(0xFF625FE8),
//         ),
//       ),
//     );
//   }
// }

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:peerup/features/tongue/bloc/tongue_twister_bloc.dart';
import 'package:peerup/features/tongue/bloc/tongue_twister_event.dart';
import 'package:peerup/features/tongue/bloc/tongue_twister_state.dart';
import 'package:peerup/models/tongue_twister.dart';

import 'TongueTwisterDetailPage.dart';

class TongueTwisterPracticePage extends StatefulWidget {
  const TongueTwisterPracticePage({super.key});

  @override
  State<TongueTwisterPracticePage> createState() =>
      _TongueTwisterPracticePageState();
}

class _TongueTwisterPracticePageState extends State<TongueTwisterPracticePage> {
  static const Color _background = Color(0xFF0B1025);
  static const Color _purple = Color(0xFF9B6DFF);
  static const Color _pink = Color(0xFFFF71C6);
  static const Color _blue = Color(0xFF58B7FF);
  static const Color _text = Color(0xFFF6F4FF);
  static const Color _muted = Color(0xFFB9BDD5);

  int _selectedCategory = 0;
  final List<String> _categories = ['For You', 'Beginner', 'Medium', 'Hard'];

  Color _parseColor(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const Color(0xFF9B6DFF);
    }
    var hex = value.trim().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return const Color(0xFF9B6DFF);
  }

  IconData _parseIcon(String? value) {
    switch (value?.toLowerCase()) {
      case 'coffee':
      case 'coffee_rounded':
        return Icons.coffee_rounded;
      case 'local_fire_department':
      case 'local_fire_department_rounded':
        return Icons.local_fire_department_rounded;
      case 'waves':
      case 'waves_rounded':
        return Icons.waves_rounded;
      case 'spa':
      case 'spa_rounded':
        return Icons.spa_rounded;
      case 'bakery_dining':
      case 'bakery_dining_rounded':
        return Icons.bakery_dining_rounded;
      case 'location_city':
      case 'location_city_rounded':
        return Icons.location_city_rounded;
      case 'set_meal':
      case 'set_meal_rounded':
        return Icons.set_meal_rounded;
      case 'pets':
      case 'pets_rounded':
        return Icons.pets_rounded;
      case 'visibility':
      case 'visibility_rounded':
        return Icons.visibility_rounded;
      case 'bug_report':
      case 'bug_report_rounded':
        return Icons.bug_report_rounded;
      case 'kitchen':
      case 'kitchen_rounded':
        return Icons.kitchen_rounded;
      case 'water':
      case 'water_rounded':
        return Icons.water_rounded;
      case 'checkroom':
      case 'checkroom_rounded':
        return Icons.checkroom_rounded;
      case 'landscape':
      case 'landscape_rounded':
        return Icons.landscape_rounded;
      case 'toys':
      case 'toys_rounded':
        return Icons.toys_rounded;
      case 'storefront':
      case 'storefront_rounded':
        return Icons.storefront_rounded;
      case 'military_tech':
      case 'military_tech_rounded':
        return Icons.military_tech_rounded;
      case 'grass':
      case 'grass_rounded':
        return Icons.grass_rounded;
      case 'forest':
      case 'forest_rounded':
        return Icons.forest_rounded;
      case 'access_time':
      case 'access_time_rounded':
        return Icons.access_time_rounded;
      case 'record_voice_over':
      case 'record_voice_over_rounded':
      default:
        return Icons.record_voice_over_rounded;
    }
  }

  List<Map<String, dynamic>> _mapTwisters(List<TongueTwister> twisters) {
    return twisters.map((twister) {
      return <String, dynamic>{
        'id': twister.id,
        'title': twister.title,
        'text': twister.text,
        'level': twister.level,
        'seconds': '${twister.seconds} sec',
        'xp': twister.xp,
        'color': _parseColor(twister.color),
        'icon': _parseIcon(twister.icon),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _filteredTwisters(
    List<Map<String, dynamic>> twisters,
  ) {
    if (_selectedCategory == 0) return twisters;
    final selectedLevel = _categories[_selectedCategory];
    return twisters
        .where(
          (item) =>
              item['level'].toString().toLowerCase() ==
              selectedLevel.toLowerCase(),
        )
        .toList();
  }

  void _openPractice(Map<String, dynamic> item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TongueTwisterDetailPage(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TongueTwisterBloc, TongueTwisterState>(
      builder: (context, state) {
        if (state is TongueTwisterInitial || state is TongueTwisterLoading) {
          return const Scaffold(
            backgroundColor: _background,
            body: _PracticeLoading(),
          );
        }

        if (state is TongueTwisterError) {
          return Scaffold(
            backgroundColor: _background,
            body: Stack(
              children: [
                const _PracticeBackdrop(),
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _GlassPanel(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              color: _pink,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Challenges unavailable',
                              style: TextStyle(
                                color: _text,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _muted,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed:
                                  () => context.read<TongueTwisterBloc>().add(
                                    FetchTongueTwisters(),
                                  ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (state is TongueTwisterLoaded) {
          final allItems = _mapTwisters(state.twisters);
          final items = _filteredTwisters(allItems);

          return Scaffold(
            backgroundColor: _background,
            body: Stack(
              children: [
                const _PracticeBackdrop(),
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_pink, _purple, _blue],
                                ),
                                borderRadius: BorderRadius.circular(19),
                                boxShadow: [
                                  BoxShadow(
                                    color: _purple.withValues(alpha: 0.30),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.record_voice_over_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SPEAK WITH CONFIDENCE',
                                    style: TextStyle(
                                      color: _pink,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Speaking Practice',
                                    style: TextStyle(
                                      color: _text,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Choose a challenge and level up',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _PracticeStats(
                          total: allItems.length,
                          visible: items.length,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 9),
                          itemBuilder: (context, index) {
                            final selected = _selectedCategory == index;
                            return _CategoryChip(
                              label: _categories[index],
                              selected: selected,
                              onTap:
                                  () =>
                                      setState(() => _selectedCategory = index),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 21),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Choose your challenge',
                                style: TextStyle(
                                  color: _text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${items.length} challenges',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 13),
                      Expanded(
                        child:
                            items.isEmpty
                                ? const Center(
                                  child: Text(
                                    'No challenges in this category yet',
                                    style: TextStyle(color: _muted),
                                  ),
                                )
                                : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    3,
                                    20,
                                    28,
                                  ),
                                  itemCount: items.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return _TwisterGlassCard(
                                      number: index + 1,
                                      item: item,
                                      onTap: () => _openPractice(item),
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

        return const Scaffold(
          backgroundColor: _background,
          body: Center(
            child: Text(
              'Something went wrong.',
              style: TextStyle(color: _text),
            ),
          ),
        );
      },
    );
  }
}

class _PracticeBackdrop extends StatelessWidget {
  const _PracticeBackdrop();

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
          top: -125,
          left: -110,
          child: _GlowOrb(
            color: const Color(0xFF995EFF).withValues(alpha: 0.23),
          ),
        ),
        Positioned(
          top: 340,
          right: -170,
          child: _GlowOrb(
            color: const Color(0xFFFF60C8).withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          bottom: -160,
          left: -120,
          child: _GlowOrb(
            color: const Color(0xFF39A9FF).withValues(alpha: 0.14),
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PracticeStats extends StatelessWidget {
  const _PracticeStats({required this.total, required this.visible});
  final int total;
  final int visible;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const _StatIcon(icon: Icons.bolt_rounded, color: Color(0xFFFFC76A)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your practice library',
                  style: TextStyle(
                    color: Color(0xFFF6F4FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total challenges to sharpen your speaking',
                  style: const TextStyle(
                    color: Color(0xFFB9BDD5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF9B6DFF).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF9B6DFF).withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              '$visible shown',
              style: const TextStyle(
                color: Color(0xFFD4C1FF),
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatIcon extends StatelessWidget {
  const _StatIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 23),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
          decoration: BoxDecoration(
            gradient:
                selected
                    ? const LinearGradient(
                      colors: [Color(0xFFB18AFF), Color(0xFF7958F5)],
                    )
                    : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color:
                  selected
                      ? const Color(0xFFC7ADFF)
                      : Colors.white.withValues(alpha: 0.13),
            ),
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: const Color(0xFF9B6DFF).withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ]
                    : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFFB9BDD5),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TwisterGlassCard extends StatelessWidget {
  const _TwisterGlassCard({
    required this.number,
    required this.item,
    required this.onTap,
  });

  final int number;
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itemColor = item['color'] as Color? ?? const Color(0xFF9B6DFF);
    final itemIcon =
        item['icon'] as IconData? ?? Icons.record_voice_over_rounded;
    final level = item['level']?.toString() ?? 'Beginner';
    final levelColor = switch (level.toLowerCase()) {
      'beginner' => const Color(0xFF5FE0BD),
      'medium' => const Color(0xFFFFC76A),
      'hard' => const Color(0xFFFF819D),
      _ => const Color(0xFFB69AFF),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(23),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.105),
                    Colors.white.withValues(alpha: 0.035),
                  ],
                ),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 57,
                    height: 61,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          itemColor.withValues(alpha: 0.32),
                          itemColor.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: itemColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(itemIcon, color: itemColor, size: 27),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'CHALLENGE ${number.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Color(0xFFB9BDD5),
                                fontSize: 9,
                                letterSpacing: 1.3,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: levelColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              level,
                              style: TextStyle(
                                color: levelColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item['title']?.toString() ?? 'Tongue Twister',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF6F4FF),
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            _MetaTag(
                              icon: Icons.timer_outlined,
                              label: item['seconds']?.toString() ?? '60 sec',
                            ),
                            _MetaTag(
                              icon: Icons.bolt_rounded,
                              label: '+${item['xp'] ?? 10} XP',
                              accent: const Color(0xFFFFC76A),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFFD4C1FF),
                      size: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({
    required this.icon,
    required this.label,
    this.accent = const Color(0xFFB9BDD5),
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeLoading extends StatelessWidget {
  const _PracticeLoading();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _PracticeBackdrop(),
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF9B6DFF)),
        ),
      ],
    );
  }
}
