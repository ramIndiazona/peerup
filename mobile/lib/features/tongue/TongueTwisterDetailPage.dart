// import 'package:flutter/material.dart';

// class TongueTwisterDetailPage extends StatefulWidget {
//   const TongueTwisterDetailPage({super.key, required this.item});

//   final Map<String, dynamic> item;

//   @override
//   State<TongueTwisterDetailPage> createState() =>
//       _TongueTwisterDetailPageState();
// }

// class _TongueTwisterDetailPageState extends State<TongueTwisterDetailPage> {
//   static const Color primary = Color(0xFF625FE8);
//   static const Color background = Color(0xFFF7F7FC);

//   final ScrollController _scrollController = ScrollController();

//   bool _isScrolling = false;
//   int _runId = 0;

//   // Reading speed: 50 logical pixels per second.
//   static const double _pixelsPerSecond = 50.0;
//   double _selectedSpeed = 1.0;

//   static const double _basePixelsPerSecond = 50.0;

//   final List<double> _speedOptions = [0.5, 1.0, 1.5, 2.0];

//   @override
//   void initState() {
//     super.initState();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) {
//         _startScrolling();
//       }
//     });
//   }

//   Future<void> _startScrolling({bool reset = true}) async {
//     if (!mounted || !_scrollController.hasClients) return;

//     final int currentRun = ++_runId;

//     if (reset) {
//       _scrollController.jumpTo(0);
//     }

//     final double maxExtent = _scrollController.position.maxScrollExtent;

//     if (maxExtent <= 0) return;

//     setState(() {
//       _isScrolling = true;
//     });

//     try {
//       while (mounted && currentRun == _runId) {
//         if (!_scrollController.hasClients) break;

//         final double remaining = maxExtent - _scrollController.offset;

//         if (remaining <= 0) break;

//         final double pixelsPerSecond = _basePixelsPerSecond * _selectedSpeed;

//         final int durationMs = ((remaining / pixelsPerSecond) * 1000).round();

//         await _scrollController.animateTo(
//           maxExtent,
//           duration: Duration(milliseconds: durationMs.clamp(1000, 3600000)),
//           curve: Curves.linear,
//         );

//         break;
//       }
//     } catch (_) {
//       // Scrolling may stop when the page is disposed.
//     }

//     if (!mounted || currentRun != _runId) return;

//     setState(() {
//       _isScrolling = false;
//     });
//   }

//   void _changeSpeed(double speed) {
//     if (_selectedSpeed == speed) return;

//     _selectedSpeed = speed;

//     if (!_scrollController.hasClients) {
//       setState(() {});
//       return;
//     }

//     // Keep the current scroll position.
//     _runId++;

//     setState(() {
//       _isScrolling = false;
//     });

//     _startScrolling(reset: false);
//   }

//   void _tryAgain() {
//     _runId++;

//     if (_scrollController.hasClients) {
//       _scrollController.jumpTo(0);
//     }

//     _startScrolling();
//   }

//   @override
//   void dispose() {
//     _runId++;
//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final String sentence = widget.item['text'] as String? ?? '';

//     return Scaffold(
//       backgroundColor: background,

//       // Minimal app bar.
//       appBar: AppBar(
//         backgroundColor: background,
//         surfaceTintColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF24243B)),
//         ),
//         title: const Text(
//           'Speaking Practice',
//           style: TextStyle(
//             color: Color(0xFF24243B),
//             fontSize: 18,
//             fontWeight: FontWeight.w800,
//           ),
//         ),
//         centerTitle: true,
//         actions: [
//           PopupMenuButton<double>(
//             tooltip: 'Scrolling speed',
//             initialValue: _selectedSpeed,
//             onSelected: _changeSpeed,
//             icon: const Icon(Icons.speed_rounded, color: primary, size: 25),
//             itemBuilder: (context) {
//               return _speedOptions.map((speed) {
//                 return PopupMenuItem<double>(
//                   value: speed,
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           '${speed}x',
//                           style: TextStyle(
//                             fontWeight:
//                                 speed == _selectedSpeed
//                                     ? FontWeight.w700
//                                     : FontWeight.w400,
//                           ),
//                         ),
//                       ),
//                       if (speed == _selectedSpeed)
//                         const Icon(
//                           Icons.check_rounded,
//                           color: primary,
//                           size: 20,
//                         ),
//                     ],
//                   ),
//                 );
//               }).toList();
//             },
//           ),
//           IconButton(
//             tooltip: 'Try again',
//             onPressed: _tryAgain,
//             icon: const Icon(Icons.refresh_rounded, color: primary, size: 25),
//           ),
//           const SizedBox(width: 8),
//         ],
//       ),

//       // Full-screen text area. No card or text container.
//       body: SafeArea(
//         child: LayoutBuilder(
//           builder: (context, constraints) {
//             final double viewportHeight = constraints.maxHeight;

//             return ClipRect(
//               child: SingleChildScrollView(
//                 controller: _scrollController,
//                 physics: const NeverScrollableScrollPhysics(),
//                 child: Column(
//                   children: [
//                     // Empty space: text enters from below.
//                     SizedBox(height: viewportHeight),

//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 28),
//                       child: Text(
//                         sentence,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           fontSize: 27,
//                           height: 2.2,
//                           letterSpacing: 0.35,
//                           fontWeight: FontWeight.w600,
//                           color: Color(0xFF303047),
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 24),

//                     // Empty space lets the final line exit at the top.
//                     SizedBox(height: viewportHeight),
//                   ],
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

import 'dart:ui';

import 'package:flutter/material.dart';

class TongueTwisterDetailPage extends StatefulWidget {
  const TongueTwisterDetailPage({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  State<TongueTwisterDetailPage> createState() =>
      _TongueTwisterDetailPageState();
}

class _TongueTwisterDetailPageState extends State<TongueTwisterDetailPage> {
  static const Color primary = Color(0xFF9B8CFF);
  static const Color background = Color(0xFF0B1020);
  static const Color surface = Color(0xFF151B30);
  static const Color muted = Color(0xFF9AA5C4);
  static const Color textPrimary = Color(0xFFF5F6FF);

  final ScrollController _scrollController = ScrollController();

  bool _isScrolling = false;
  int _runId = 0;

  static const double _basePixelsPerSecond = 50.0;
  double _selectedSpeed = 1.0;

  final List<double> _speedOptions = [0.5, 1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startScrolling();
    });
  }

  Future<void> _startScrolling({bool reset = true}) async {
    if (!mounted || !_scrollController.hasClients) return;

    final int currentRun = ++_runId;
    if (reset) _scrollController.jumpTo(0);

    final double maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;

    setState(() => _isScrolling = true);

    try {
      while (mounted && currentRun == _runId) {
        if (!_scrollController.hasClients) break;
        final double remaining = maxExtent - _scrollController.offset;
        if (remaining <= 0) break;

        final double pixelsPerSecond = _basePixelsPerSecond * _selectedSpeed;
        final int durationMs = ((remaining / pixelsPerSecond) * 1000).round();

        await _scrollController.animateTo(
          maxExtent,
          duration: Duration(milliseconds: durationMs.clamp(1000, 3600000)),
          curve: Curves.linear,
        );
        break;
      }
    } catch (_) {
      // Scrolling can stop while the page is being disposed.
    }

    if (!mounted || currentRun != _runId) return;
    setState(() => _isScrolling = false);
  }

  void _changeSpeed(double speed) {
    if (_selectedSpeed == speed) return;
    _selectedSpeed = speed;

    if (!_scrollController.hasClients) {
      setState(() {});
      return;
    }

    _runId++;
    setState(() => _isScrolling = false);
    _startScrolling(reset: false);
  }

  void _tryAgain() {
    _runId++;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _startScrolling();
  }

  @override
  void dispose() {
    _runId++;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String sentence = widget.item['text'] as String? ?? '';
    final String title = widget.item['title'] as String? ?? 'Speaking Practice';
    final String level = widget.item['level'] as String? ?? 'Practice';
    final int xp = (widget.item['xp'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded, color: textPrimary),
          ),
        ),
        title: Column(
          children: [
            const Text(
              'SPEAKING PRACTICE',
              style: TextStyle(
                color: muted,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<double>(
            tooltip: 'Scrolling speed',
            initialValue: _selectedSpeed,
            color: surface,
            onSelected: _changeSpeed,
            icon: const Icon(Icons.speed_rounded, color: primary, size: 24),
            itemBuilder:
                (context) =>
                    _speedOptions.map((speed) {
                      final bool selected = speed == _selectedSpeed;
                      return PopupMenuItem<double>(
                        value: speed,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${speed}x',
                                style: TextStyle(
                                  color: selected ? primary : textPrimary,
                                  fontWeight:
                                      selected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_rounded,
                                color: primary,
                                size: 18,
                              ),
                          ],
                        ),
                      );
                    }).toList(),
          ),
          IconButton(
            tooltip: 'Try again',
            onPressed: _tryAgain,
            icon: const Icon(Icons.refresh_rounded, color: primary, size: 23),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double viewportHeight = constraints.maxHeight;

            return Stack(
              children: [
                const Positioned(
                  top: -90,
                  left: -100,
                  child: _GlowOrb(color: Color(0xFF695CFF), size: 250),
                ),
                const Positioned(
                  top: 180,
                  right: -130,
                  child: _GlowOrb(color: Color(0xFF247DE8), size: 260),
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: _GlassPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8B7CFF),
                                    Color(0xFF4C9DFF),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.record_voice_over_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    level.toUpperCase(),
                                    style: const TextStyle(
                                      color: primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Follow the text at your own pace',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (xp > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFC66D,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFFC66D,
                                    ).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  '+$xp XP',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD28B),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ClipRect(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              SizedBox(height: viewportHeight * 0.72),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                ),
                                child: _GlassPanel(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 28,
                                  ),
                                  radius: 28,
                                  borderColor: primary.withValues(alpha: 0.24),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 54,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: primary.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        sentence,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 26,
                                          height: 2.0,
                                          letterSpacing: 0.3,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.graphic_eq_rounded,
                                            color: primary.withValues(
                                              alpha: 0.9,
                                            ),
                                            size: 19,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'READ CLEARLY · STAY RELAXED',
                                            style: TextStyle(
                                              color: muted,
                                              fontSize: 9,
                                              letterSpacing: 1.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: viewportHeight * 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                      child: _GlassPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        radius: 20,
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primary.withValues(alpha: 0.14),
                              ),
                              child: Icon(
                                _isScrolling
                                    ? Icons.graphic_eq_rounded
                                    : Icons.check_rounded,
                                color: primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isScrolling
                                        ? 'Auto-scroll is running'
                                        : 'Ready to practise',
                                    style: const TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Speed ${_selectedSpeed}x · Use ↻ to restart',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  _isScrolling
                                      ? 'Restart reading'
                                      : 'Start reading',
                              onPressed: _tryAgain,
                              style: IconButton.styleFrom(
                                backgroundColor: primary.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                color: primary,
                                size: 25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.11),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
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

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}
