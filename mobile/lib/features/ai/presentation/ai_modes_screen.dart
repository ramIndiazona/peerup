import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_content.dart';
import '../../../models/ai.dart';
import '../bloc/ai_catalog_cubit.dart';
import '../bloc/ai_session_cubit.dart';

class AIModesScreen extends StatefulWidget {
  const AIModesScreen({super.key});

  @override
  State<AIModesScreen> createState() => _AIModesScreenState();
}

class _AIModesScreenState extends State<AIModesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final cubit = context.read<AICatalogCubit>();
      if (!cubit.state.characters.isLoaded &&
          !cubit.state.characters.isLoading) {
        cubit.load();
      }
    });
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('AI Practice')),
      body: BlocBuilder<AICatalogCubit, AICatalogState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.secondary, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.record_voice_over_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Practice with an AI partner that never judges.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Characters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
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
             
             
              Text(
                'Try a scenario',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              AsyncContent(
                value: state.scenarios,
                data:
                    (items) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in items)
                          ActionChip(
                            label: Text(s),
                            avatar: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                            ),
                            onPressed: () => _start(context, scenario: s),
                          ),
                      ],
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CharacterCard extends StatelessWidget {
  const CharacterCard({required this.character, required this.onTap});

  final AICharacter character;
  final VoidCallback onTap;

  String _imageUrl() {
    final avatar = character.avatar;

    if (avatar == null || avatar.trim().isEmpty) {
      return '';
    }

    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }

    return 'http://localhost:3100$avatar';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),

        // Bottom shadow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 7,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 0.68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // --------------------------------
                  // CHARACTER IMAGE
                  // --------------------------------
                  imageUrl.isNotEmpty
                      ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _imagePlaceholder();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }

                          return Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      )
                      : _imagePlaceholder(),

                  // --------------------------------
                  // BOTTOM DARK GRADIENT
                  // --------------------------------
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 100,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            //  Colors.transparent,
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --------------------------------
                  // TOP RIGHT ICON
                  // --------------------------------
                  // Positioned(
                  //   top: 10,
                  //   right: 10,
                  //   child: Container(
                  //     width: 32,
                  //     height: 32,
                  //     decoration: BoxDecoration(
                  //       color: Colors.white.withValues(alpha: 0.92),
                  //       shape: BoxShape.circle,
                  //       boxShadow: [
                  //         BoxShadow(
                  //           color: Colors.black.withValues(alpha: 0.12),
                  //           blurRadius: 4,
                  //           offset: const Offset(0, 2),
                  //         ),
                  //       ],
                  //     ),
                  //     child: const Icon(
                  //       Icons.mail_outline_rounded,
                  //       size: 18,
                  //       color: Color(0xFF9E9E9E),
                  //     ),
                  //   ),
                  // ),

                  // --------------------------------
                  // CHARACTER NAME
                  // --------------------------------
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 12,
                    child: Text(
                      character.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
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

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Text(
        character.name.isNotEmpty ? character.name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
