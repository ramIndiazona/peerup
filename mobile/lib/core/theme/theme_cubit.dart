import 'package:flutter_bloc/flutter_bloc.dart';

enum AppThemeMode { light, dark }

class ThemeCubit extends Cubit<AppThemeMode> {
  ThemeCubit() : super(AppThemeMode.light);

  bool get isDark => state == AppThemeMode.dark;

  void toggleDark(bool dark) =>
      emit(dark ? AppThemeMode.dark : AppThemeMode.light);
}
