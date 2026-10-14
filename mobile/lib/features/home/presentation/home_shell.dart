import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../live/cubit/live_cubit.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const Color _background = Color(0xFF0B1020);
  static const Color _primary = Color(0xFF9B8CFF);
  static const Color _muted = Color(0xFF9AA5C4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<LiveCubit>().enter());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.navigationShell.currentIndex == 0) {
      unawaited(context.read<LiveCubit>().enter());
    }
  }

  void _onTap(BuildContext context, int index) {
    final wasMatch = widget.navigationShell.currentIndex == 0;

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );

    final isMatch = index == 0;
    if (isMatch && !wasMatch) {
      unawaited(context.read<LiveCubit>().enter());
    } else if (!isMatch && wasMatch) {
      context.read<LiveCubit>().exit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = widget.navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: _background,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned(
            top: -150,
            left: -130,
            child: _NavigationGlow(color: Color(0xFF695CFF), size: 320),
          ),
          const Positioned(
            bottom: 30,
            right: -150,
            child: _NavigationGlow(color: Color(0xFF247DE8), size: 300),
          ),
          widget.navigationShell,
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF151B30).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  height: 72,
                  indicatorColor: _primary.withValues(alpha: 0.16),
                  labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                    (states) => TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.2,
                      fontWeight:
                          states.contains(WidgetState.selected)
                              ? FontWeight.w800
                              : FontWeight.w500,
                      color:
                          states.contains(WidgetState.selected)
                              ? _primary
                              : _muted,
                    ),
                  ),
                  iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
                    (states) => IconThemeData(
                      size: 23,
                      color:
                          states.contains(WidgetState.selected)
                              ? _primary
                              : _muted,
                    ),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (i) => _onTap(context, i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.smart_toy_outlined),
                      selectedIcon: Icon(Icons.smart_toy_rounded),
                      label: 'AI Practice',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.forum_outlined),
                      selectedIcon: Icon(Icons.forum_rounded),
                      label: 'Tongue Twisters',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationGlow extends StatelessWidget {
  const _NavigationGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.17),
          ),
        ),
      ),
    );
  }
}
