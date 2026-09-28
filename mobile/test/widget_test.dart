import 'package:flutter_test/flutter_test.dart';
import 'package:peerup/app.dart';
import 'package:peerup/core/auth/auth_repository.dart';
import 'package:peerup/core/auth/auth_service.dart';
import 'package:peerup/core/auth/token_manager.dart';
import 'package:peerup/core/network/api_client.dart';
import 'package:peerup/core/router/app_router.dart';
import 'package:peerup/core/storage/token_storage.dart';
import 'package:peerup/core/theme/theme_cubit.dart';
import 'package:peerup/features/auth/bloc/auth_cubit.dart';

class FakeTokenStorage extends TokenStorage {
  String? access;
  String? refresh;
  String? user;

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<String?> get cachedUser async => user;

  @override
  Future<bool> hasSession() async => access != null;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> saveUser(String json) async => user = json;

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
    user = null;
  }
}

void main() {
  testWidgets('redirects a logged-out user to the login screen', (
    tester,
  ) async {
    final tokens = FakeTokenStorage();
    final tokenManager = TokenManager(storage: tokens);
    final apiClient = ApiClient(tokens: tokenManager);
    final authService = AuthService(
      repo: AuthRepository(apiClient),
      tokens: tokenManager,
    );
    final authCubit = AuthCubit(auth: authService);
    final themeCubit = ThemeCubit();
    final router = AppRouter(authCubit: authCubit).router;

    await tester.pumpWidget(
      PeerUpApp(router: router, authCubit: authCubit, themeCubit: themeCubit),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
