import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/models/quiz_model.dart';
import 'package:quiz_app/services/api_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        user:      clearUser  ? null  : user      ?? this.user,
        isLoading: isLoading                       ?? this.isLoading,
        error:     clearError ? null  : error      ?? this.error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // ApiService already restored the session in main() — read static fields.
    final userId = ApiService.userId;
    if (userId != null) {
      return AuthState(
        user: UserModel(
          id:    userId,
          name:  ApiService.name  ?? '',
          email: ApiService.email ?? '',
          role:  ApiService.role  ?? 'STUDENT',
        ),
      );
    }
    return const AuthState();
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ApiService.login(email.trim(), password);
      if (data.containsKey('error')) {
        state = state.copyWith(isLoading: false, error: data['error'] as String);
        return false;
      }
      if (data['role'] == 'TEACHER') {
        await ApiService.logout();
        state = state.copyWith(
          isLoading: false,
          error: 'This app is for students only. Please use the Teacher app.',
        );
        return false;
      }
      state = AuthState(user: UserModel.fromJson(data));
      return true;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Connection failed. Check your server.',
      );
      return false;
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ApiService.register(
        name.trim(), email.trim(), password, role: 'STUDENT',
      );
      if (data.containsKey('error')) {
        state = state.copyWith(isLoading: false, error: data['error'] as String);
        return false;
      }
      state = AuthState(user: UserModel.fromJson(data));
      return true;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Connection failed. Check your server.',
      );
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await ApiService.logout();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);