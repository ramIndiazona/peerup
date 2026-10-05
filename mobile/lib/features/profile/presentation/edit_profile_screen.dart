import 'package:flutter/material.dart';
import '../../../core/widgets/user_avatar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../models/enums.dart';
import '../bloc/profile_cubit.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _country;
  final _goals = TextEditingController();
  final _interestsField = TextEditingController();
  EnglishLevel _level = EnglishLevel.b1;
  bool _showAge = false;
  bool _showGender = true;
  bool _busy = false;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final profile = context.read<ProfileCubit>().state.value?.profile;
    _name = TextEditingController(text: profile?.name ?? '');
    _bio = TextEditingController(text: profile?.bio ?? '');
    _country = TextEditingController(text: profile?.country ?? '');
    _goals.text = (profile?.conversationGoals ?? []).join(', ');
    _level = profile?.englishLevel ?? EnglishLevel.b1;
    _showAge = profile?.showAge ?? false;
    _showGender = profile?.showGender ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _country.dispose();
    _goals.dispose();
    _interestsField.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    // Launcher phase: avatar upload wires here via storage/avatar (base64).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Photo picker arrives in a later phase. '
          'The upload endpoint (storage/avatar) is wired on the backend.',
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final goals =
          _goals.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
      final newInterests =
          _interestsField.text
              .split(',')
              .map((e) => e.trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toList();
      final patch = <String, dynamic>{
        'name': _name.text.trim(),
        if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
        if (_country.text.trim().isNotEmpty) 'country': _country.text.trim(),
        'englishLevel': _level.api,
        'conversationGoals': goals,
        if (newInterests.isNotEmpty) 'interests': newInterests,
        'showAge': _showAge,
        'showGender': _showGender,
      };
      await context.read<ProfileCubit>().save(patch);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved')));
      context.pop();
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
    final theme = Theme.of(context);
    final profile = context.watch<ProfileCubit>().state.value?.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  if (profile != null)
                    UserAvatar(
                      url: profile.avatar,
                      name: profile.name,
                      radius: 44,
                    ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _bio,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Bio',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _country,
            decoration: const InputDecoration(
              labelText: 'Country',
              prefixIcon: Icon(Icons.public_rounded),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<EnglishLevel>(
            value: _level,
            decoration: const InputDecoration(labelText: 'English level'),
            items:
                EnglishLevel.values
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text('${e.api} (CEFR)'),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => _level = v ?? _level),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _goals,
            decoration: const InputDecoration(
              labelText: 'Goals (comma separated)',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _interestsField,
            decoration: const InputDecoration(
              labelText: 'Add interests (comma separated)',
              prefixIcon: Icon(Icons.interests_outlined),
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show my age'),
            value: _showAge,
            onChanged: (v) => setState(() => _showAge = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show my gender'),
            value: _showGender,
            onChanged: (v) => setState(() => _showGender = v),
          ),
          const SizedBox(height: 16),
          LoadingButton(
            label: 'Save changes',
            loading: _busy,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
