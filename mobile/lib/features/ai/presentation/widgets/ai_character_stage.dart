// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';

// import '../../../../core/config/app_config.dart';
// import '../../../../core/theme/app_colors.dart';
// import '../../../../models/ai.dart';

// /// Lightweight visual state of the AI character during a Practice session.
// enum AICharacterState { idle, thinking, speaking }

// /// Large, animated AI character stage.
// ///
// /// The avatar occupies a significant part of the screen (it is the focus of the
// /// experience, not a small chat bubble) and animates according to the current
// /// [state]:
// ///  * idle     -> slow breathing / floating
// ///  * thinking -> slower float plus a thinking indicator
// ///  * speaking -> continuous pulse while TTS is actually playing
// class AICharacterStage extends StatefulWidget {
//   const AICharacterStage({
//     super.key,
//     required this.character,
//     required this.state,
//     this.size = 220,
//   });

//   final AICharacter? character;
//   final AICharacterState state;
//   final double size;

//   @override
//   State<AICharacterStage> createState() => _AICharacterStageState();
// }

// class _AICharacterStageState extends State<AICharacterStage>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 2200),
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         SizedBox(
//           height: widget.size,
//           width: widget.size,
//           child: AnimatedBuilder(
//             animation: _controller,
//             builder: (context, child) {
//               final v = _controller.value;

//               // Sine-ish motion from the controller value (0..1 -> -1..1).
//               final wave = (v < 0.5 ? v * 2 : (1 - v) * 2) * 2 - 1;

//               final scale = switch (widget.state) {
//                 AICharacterState.speaking => 1 + 0.03 * wave,
//                 AICharacterState.thinking => 1 + 0.008 * wave,
//                 AICharacterState.idle => 1 + 0.012 * wave,
//               };

//               final dy = switch (widget.state) {
//                 AICharacterState.speaking => -4.0 * wave,
//                 AICharacterState.thinking => -2.0 * wave,
//                 AICharacterState.idle => -3.0 * wave,
//               };

//               return Transform.translate(
//                 offset: Offset(0, dy),
//                 child: Transform.scale(scale: scale, child: child),
//               );
//             },
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(widget.size / 3),
//               child: _Avatar(character: widget.character, size: widget.size),
//             ),
//           ),
//         ),
//         const SizedBox(height: 14),
//         Text(
//           widget.character?.name ?? 'AI Partner',
//           style: theme.textTheme.titleLarge?.copyWith(
//             fontWeight: FontWeight.w800,
//           ),
//         ),
//         const SizedBox(height: 6),
//         _StatusPill(state: widget.state),
//       ],
//     );
//   }
// }

// class _Avatar extends StatelessWidget {
//   const _Avatar({required this.character, required this.size});

//   final AICharacter? character;
//   final double size;

//   @override
//   Widget build(BuildContext context) {
//     final url = AppConfig.resolveAssetUrl(character?.avatar);

//     if (url.isEmpty) {
//       return _placeholder(context);
//     }

//     return CachedNetworkImage(
//       imageUrl: url,
//       width: size,
//       height: size,
//       fit: BoxFit.cover,
//       placeholder:
//           (context, _) => Container(
//             color: Colors.grey.shade200,
//             alignment: Alignment.center,
//             child: const SizedBox(
//               width: 24,
//               height: 24,
//               child: CircularProgressIndicator(strokeWidth: 2.4),
//             ),
//           ),
//       errorWidget: (context, _, __) => _placeholder(context),
//     );
//   }

//   Widget _placeholder(BuildContext context) {
//     final name = character?.name ?? '';
//     return Container(
//       color: AppColors.primary.withValues(alpha: 0.12),
//       alignment: Alignment.center,
//       child: Text(
//         name.isEmpty ? 'AI' : name.characters.first.toUpperCase(),
//         style: TextStyle(
//           fontSize: size * 0.3,
//           fontWeight: FontWeight.w800,
//           color: AppColors.primary,
//         ),
//       ),
//     );
//   }
// }

// class _StatusPill extends StatelessWidget {
//   const _StatusPill({required this.state});

//   final AICharacterState state;

//   @override
//   Widget build(BuildContext context) {
//     final (label, color) = switch (state) {
//       AICharacterState.idle => ('Ready to practice', AppColors.success),
//       AICharacterState.thinking => ('Thinking...', AppColors.warning),
//       AICharacterState.speaking => ('Speaking', AppColors.primary),
//     };

//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 220),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.12),
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           if (state == AICharacterState.thinking)
//             _ThinkingDots(color: color)
//           else
//             Icon(Icons.circle, size: 8, color: color),
//           const SizedBox(width: 8),
//           Text(
//             label,
//             style: Theme.of(context).textTheme.labelMedium?.copyWith(
//               color: color,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _ThinkingDots extends StatefulWidget {
//   const _ThinkingDots({required this.color});

//   final Color color;

//   @override
//   State<_ThinkingDots> createState() => _ThinkingDotsState();
// }

// class _ThinkingDotsState extends State<_ThinkingDots>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 900),
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _controller,
//       builder: (context, _) {
//         return Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             for (var i = 0; i < 3; i++)
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 1.5),
//                 child: Opacity(
//                   opacity: _dotOpacity(i),
//                   child: Container(
//                     width: 6,
//                     height: 6,
//                     decoration: BoxDecoration(
//                       color: widget.color,
//                       shape: BoxShape.circle,
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         );
//       },
//     );
//   }

//   double _dotOpacity(int index) {
//     final phase = (_controller.value - index * 0.2) % 1.0;
//     return phase < 0.5 ? 0.3 + phase : 0.8 - (phase - 0.5);
//   }
// }

import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class AICharacterStage extends StatefulWidget {
  const AICharacterStage({super.key, required this.isSpeaking});

  final bool isSpeaking;

  @override
  State<AICharacterStage> createState() => _AICharacterStageState();
}

class _AICharacterStageState extends State<AICharacterStage> {
  StateMachineController? _controller;

  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1',
    );

    if (controller == null) {
      debugPrint('❌ State Machine 1 NOT FOUND');
      return;
    }

    artboard.addController(controller);
    _controller = controller;

    debugPrint('========== RIVE INPUTS ==========');

    for (final input in controller.inputs) {
      debugPrint('INPUT: ${input.name} | TYPE: ${input.runtimeType}');
    }

    debugPrint('=================================');
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 420,
      child: RiveAnimation.asset(
        'assets/characters/ai_character.riv',
        fit: BoxFit.contain,
        onInit: _onRiveInit,
      ),
    );
  }
}

StateMachineController? _controller;

@override
void dispose() {
  _controller?.dispose();
}

void _onRiveInit(Artboard artboard) {
  final controller = StateMachineController.fromArtboard(
    artboard,
    'State Machine 1',
  );

  if (controller == null) {
    debugPrint('❌ State Machine 1 not found');
    return;
  }

  artboard.addController(controller);
  _controller = controller;

  debugPrint('✅ Rive State Machine loaded');
}

@override
Widget build(BuildContext context) {
  return SizedBox(
    width: 320,
    height: 420,
    child: RiveAnimation.asset(
      'assets/characters/ai_character.riv',
      fit: BoxFit.contain,
      onInit: _onRiveInit,
    ),
  );
}
