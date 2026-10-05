import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_content.dart';
import '../../../models/ai.dart';
import '../bloc/ai_catalog_cubit.dart';
import '../bloc/ai_session_cubit.dart';

/// Practice setup: pick an AI character, pick a scenario, start practicing.
///
/// Both lists come from the existing AI APIs (no hardcoded data).
class PracticeSetupScreen extends StatefulWidget {
  const PracticeSetupScreen({super.key});

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  AICharacter? _character;
  String? _scenario;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<AICatalogCubit>();
      if (!cubit.state.characters.isLoaded &&
          !cubit.state.characters.isLoading) {
        cubit.load();
      }
    });
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);

    try {
      final characters =
          context.read<AICatalogCubit>().state.characters.valueOrNull ??
          const <AICharacter>[];

      // Always creates a new AI session on the backend.
      await context.read<AISessionCubit>().start(
        characterId: _character?.id,
        scenario: _scenario,
        characters: characters,
      );

      if (!mounted) return;
      context.push(AppRoutes.practiceSession);
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendly(e))));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  String _friendly(Object error) {
    final text = '$error';
    if (text.contains('No connection')) {
      return 'No connection to the server. Check your network.';
    }
    if (text.contains('CHARACTER_NOT_FOUND')) {
      return 'This character is not available anymore.';
    }
    return 'Could not start practice. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgLight,
        title: const Text('Practice'),
      ),
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
                        'Choose a partner and a scenario, then start talking.',
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
                '1. Choose a character',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              AsyncContent(
                value: state.characters,
                error:
                    (error, _) => Column(
                      children: [
                        const Text('Could not load characters.'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed:
                              () => context.read<AICatalogCubit>().load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                data:
                    (items) => GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                      itemBuilder: (context, index) {
                        final character = items[index];
                        return _CharacterTile(
                          character: character,
                          selected: _character?.id == character.id,
                          onTap:
                              () => setState(() {
                                _character = character;
                                _scenario ??= character.scenario;
                              }),
                        );
                      },
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                '2. Choose a scenario',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              AsyncContent(
                value: state.scenarios,
                error:
                    (error, _) => Column(
                      children: [
                        const Text('Could not load scenarios.'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed:
                              () => context.read<AICatalogCubit>().load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                data:
                    (items) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final scenario in items)
                          ChoiceChip(
                            label: Text(scenario),
                            selected: _scenario == scenario,
                            onSelected:
                                (selected) => setState(() {
                                  _scenario = selected ? scenario : null;
                                }),
                          ),
                      ],
                    ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: FilledButton.icon(
            onPressed: _starting ? null : _start,
            icon:
                _starting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Practice'),
          ),
        ),
      ),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  final AICharacter character;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2.5,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _CharacterImage(character: character),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              character.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (character.isPremium)
              Icon(
                Icons.workspace_premium_rounded,
                size: 14,
                color: AppColors.warning,
              ),
          ],
        ),
      ),
    );
  }
}

class _CharacterImage extends StatelessWidget {
  const _CharacterImage({required this.character});

  final AICharacter character;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.resolveAssetUrl(character.avatar);

    if (url.isEmpty) {
      return Container(
        color: AppColors.primary.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Text(
          character.name.isEmpty
              ? 'AI'
              : character.name.characters.first.toUpperCase(),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, _) => Container(color: Colors.grey.shade200),
      errorWidget:
          (context, _, __) => Container(
            color: AppColors.primary.withValues(alpha: 0.12),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_rounded,
              size: 30,
              color: AppColors.primary,
            ),
          ),
    );
  }
}
