import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_routes.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/loading_button.dart';
import '../../models/auth_result.dart';
import '../../models/enums.dart';
import '../../models/profile.dart';
import '../auth/bloc/auth_cubit.dart';
import '../profile/bloc/profile_cubit.dart';
import '../profile/profile_repository.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _busy = false;

  final goals = [
    'Improve speaking confidence',
    'Prepare for travel',
    'Prepare for interviews',
    'Business English',
    'Casual conversation',
    'IELTS / TOEFL prep',
  ];

  String? _nativeLanguage;
  String? _learningLanguage;
  EnglishLevel _level = EnglishLevel.b1;
  final Set<String> _selectedGoals = {};
  final List<Interest> _available = [];
  final Set<String> _selectedInterests = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final repo = context.read<ProfileRepository>();
    Future.microtask(() async {
      try {
        final interests = await repo.listInterests();
        if (!mounted) return;
        setState(() => _available.addAll(interests));
      } catch (_) {
        // ignore
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_busy) return;
    if (_page < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_selectedGoals.isEmpty || _selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one goal and one interest'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final patch = <String, dynamic>{
        'englishLevel': _level.api,
        'nativeLanguage': _nativeLanguage ?? 'Portuguese',
        'learningLanguage': _learningLanguage ?? 'English',
        'conversationGoals': _selectedGoals.toList(),
        'interests': _selectedInterests.toList(),
        'onboardingCompleted': true,
      };
      await context.read<ProfileCubit>().save(patch);
      if (!mounted) return;
      final auth = context.read<AuthCubit>().state;
      await context.read<AuthCubit>().updateIdentity(
        UserIdentity(
          id: auth.user?.id ?? '',
          email: auth.user?.email ?? '',
          name: auth.user?.name ?? '',
          avatar: auth.user?.avatar,
          onboardingCompleted: true,
          role: auth.user?.role ?? UserRole.user,
        ),
      );
      if (!mounted) return;
      context.go(AppRoutes.homeMatch);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Step ${_page + 1} of 3',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_page + 1) / 3,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _LanguageStep(
                      native: _nativeLanguage,
                      learning: _learningLanguage,
                      level: _level,
                      onNative: (v) => setState(() => _nativeLanguage = v),
                      onLearning: (v) => setState(() => _learningLanguage = v),
                      onLevel: (v) => setState(() => _level = v),
                    ),
                    _GoalsStep(
                      goals: goals,
                      selected: _selectedGoals,
                      onToggle:
                          (goal) => setState(() {
                            _selectedGoals.contains(goal)
                                ? _selectedGoals.remove(goal)
                                : _selectedGoals.add(goal);
                          }),
                    ),
                    _InterestsStep(
                      interests: _available,
                      selected: _selectedInterests,
                      onToggle:
                          (interest) => setState(() {
                            _selectedInterests.contains(interest)
                                ? _selectedInterests.remove(interest)
                                : _selectedInterests.add(interest);
                          }),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: LoadingButton(
                    label: _page == 2 ? 'Let\'s go' : 'Continue',
                    loading: _busy,
                    onPressed: _next,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({
    required this.native,
    required this.learning,
    required this.level,
    required this.onNative,
    required this.onLearning,
    required this.onLevel,
  });

  final String? native;
  final String? learning;
  final EnglishLevel level;
  final ValueChanged<String> onNative;
  final ValueChanged<String> onLearning;
  final ValueChanged<EnglishLevel> onLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Let\'s set you up', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Tell us about your languages and level.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          initialValue: native,
          decoration: const InputDecoration(
            labelText: 'Native language',
            prefixIcon: Icon(Icons.translate_rounded),
          ),
          onChanged: onNative,
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: learning,
          decoration: const InputDecoration(
            labelText: 'Language you want to practice',
            prefixIcon: Icon(Icons.language_rounded),
          ),
          onChanged: onLearning,
        ),
        const SizedBox(height: 18),
        Text(
          'Your English level',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<EnglishLevel>(
          segments:
              EnglishLevel.values
                  .map((e) => ButtonSegment(value: e, label: Text(e.api)))
                  .toList(),
          selected: {level},
          onSelectionChanged: (s) => onLevel(s.first),
        ),
      ],
    );
  }
}

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({
    required this.goals,
    required this.selected,
    required this.onToggle,
  });

  final List<String> goals;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('What are your goals?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Select all that apply.', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children:
                goals
                    .map(
                      (g) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: choice(context, g, selected.contains(g)),
                      ),
                    )
                    .toList(),
          ),
        ),
      ],
    );
  }

  Widget choice(BuildContext context, String label, bool isSelected) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onToggle(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
            width: 1.6,
          ),
          color: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: isSelected ? 0.12 : 0),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (isSelected) const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _InterestsStep extends StatelessWidget {
  const _InterestsStep({
    required this.interests,
    required this.selected,
    required this.onToggle,
  });

  final List<Interest> interests;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your interests', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'We match you with people who share them.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        if (interests.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    interests
                        .map(
                          (i) => FilterChip(
                            label: Text(i.name),
                            selected: selected.contains(i.name),
                            onSelected: (_) => onToggle(i.name),
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
      ],
    );
  }
}
