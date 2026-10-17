import 'package:flutter/material.dart';

/// Overlays a small count badge on top of [child].
///
/// Used by the AppBar notification icon. When [count] is zero nothing is
/// rendered, so the surrounding layout is unchanged.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    super.key,
    required this.count,
    required this.child,
    this.max = 99,
    this.color = const Color(0xFFFF5A7A),
  });

  final int count;
  final Widget child;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    final label = count > max ? '$max+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF0B1020), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
