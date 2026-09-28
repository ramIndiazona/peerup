import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_service.dart';
import '../../../models/auth_result.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

class AuthState extends Equatable {
  const AuthState({required this.status, this.user});

  final AuthStatus status;
  final UserIdentity? user;

  AuthState copyWith({AuthStatus? status, UserIdentity? user}) {
    return AuthState(status: status ?? this.status, user: user ?? this.user);
  }

  @override
  List<Object?> get props => [status, user];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required AuthService auth})
    : _auth = auth,
      super(const AuthState(status: AuthStatus.unknown)) {
    restore();
  }

  final AuthService _auth;

  Future<void> restore() async {
    debugPrint('[AUTH] restore started');

    try {
      final raw = await _auth.cachedUser;

      if (raw != null && raw.isNotEmpty) {
        try {
          final user = UserIdentity.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );

          debugPrint('[AUTH] cached user found');
          debugPrint(
            '[AUTH] onboardingCompleted = ${user.onboardingCompleted}',
          );

          emit(AuthState(status: AuthStatus.loggedIn, user: user));
          return;
        } catch (e) {
          debugPrint('[AUTH] cached user parse error: $e');
        }
      }

      final hasSession = await _auth.hasSession();

      debugPrint('[AUTH] hasSession = $hasSession');

      if (hasSession) {
        emit(const AuthState(status: AuthStatus.loggedIn));
        return;
      }

      emit(const AuthState(status: AuthStatus.loggedOut));
    } catch (e, stackTrace) {
      debugPrint('[AUTH] restore error: $e');
      debugPrint('$stackTrace');
      emit(const AuthState(status: AuthStatus.loggedOut));
    }
  }

  Future<void> login({required String email, required String password}) async 
  {
    final result = await _auth.login(email: email, password: password);
    emit(AuthState(status: AuthStatus.loggedIn, user: result.user));
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String avatar,
    String? gender,
    String? englishLevel,
  }) async 
  {
    final result = await _auth.register(
      email: email,
      password: password,
      name: name,
      avatar: avatar,
      gender: gender,
      englishLevel: englishLevel,
    );
    emit(AuthState(status: AuthStatus.loggedIn, user: result.user));
  }

  Future<void> updateIdentity(UserIdentity identity) async {
    await _auth.updateIdentity(identity);
    emit(state.copyWith(user: identity));
  }

  Future<void> logout() async {
    await _auth.logout();
    emit(const AuthState(status: AuthStatus.loggedOut));
  }
}
