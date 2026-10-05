import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_routes.dart';
import '../../../core/widgets/avatar_selector.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../models/enums.dart';
import '../bloc/auth_cubit.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  Gender? _gender;
  EnglishLevel _level = EnglishLevel.b1;
  bool _busy = false;
  bool _choosingAvatar = false;
  String? _selectedAvatar;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_choosingAvatar) {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _choosingAvatar = true);
      return;
    }
    if (_selectedAvatar == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an avatar')));
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthCubit>().register(
        email: _email.text,
        password: _password.text,
        name: _name.text,
        avatar: _selectedAvatar!,
        gender: _gender?.api,
        englishLevel: _level.api,
      );
      if (!mounted) return;
      context.go(AppRoutes.onboarding);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Something went wrong ($e)')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 72)),
                  const SizedBox(height: 18),
                  Text(
                    _choosingAvatar
                        ? 'Choose your avatar'
                        : 'Create your account',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _choosingAvatar
                        ? 'Select an avatar for your profile'
                        : 'Start your English journey',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!_choosingAvatar) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'English level',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<EnglishLevel>(
                      value: _level,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items:
                          EnglishLevel.values
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text('${e.api} - ${e.api} (CEFR)'),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _level = v ?? _level),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          Gender.values
                              .map(
                                (g) => ChoiceChip(
                                  label: Text(g.label),
                                  selected: _gender == g,
                                  onSelected:
                                      (_) => setState(() => _gender = g),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                  if (_choosingAvatar) ...[
                    AvatarSelector(
                      selected: _selectedAvatar,
                      onSelected:
                          _busy
                              ? null
                              : (id) => setState(() => _selectedAvatar = id),
                    ),
                    TextButton(
                      onPressed:
                          _busy
                              ? null
                              : () => setState(() => _choosingAvatar = false),
                      child: const Text('Back to details'),
                    ),
                  ],
                  const SizedBox(height: 26),
                  LoadingButton(
                    label: _choosingAvatar ? 'Create account' : 'Continue',
                    loading: _busy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: theme.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed:
                            _busy ? null : () => context.go(AppRoutes.login),
                        child: const Text('Log in'),
                      ),
                    ],
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
