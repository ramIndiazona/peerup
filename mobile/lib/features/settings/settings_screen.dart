import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_cubit.dart';
import '../auth/bloc/auth_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<ThemeCubit, AppThemeMode>(
        builder: (context, mode) {
          final dark = mode == AppThemeMode.dark;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              SwitchListTile(
                secondary: Icon(
                  dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Dark mode'),
                value: dark,
                onChanged: (v) => context.read<ThemeCubit>().toggleDark(v),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.storage_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('API server'),
                subtitle: Text(AppConfig.apiBaseUrl),
                dense: true,
              ),
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Version'),
                subtitle: const Text('0.1.0 (Phase 9 scaffold)'),
                dense: true,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Log out',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () async {
                  await context.read<AuthCubit>().logout();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
