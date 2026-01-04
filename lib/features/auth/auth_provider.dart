import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../repositories/auth_repository.dart';

import '../../repositories/user_repository.dart';

/// Provides the current [User] if logged in, or null.
final authUserProvider = StreamProvider<User?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges.map((state) => state.session?.user);
});

/// Provides the full [UserModel] details including role and outlet.
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authUserAsync = ref.watch(authUserProvider);
  
  return authUserAsync.when(
    data: (user) async {
      if (user == null) return null;
      final userRepo = ref.watch(userRepositoryProvider);
      return await userRepo.getUserProfile(user.id);
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Combined state for Auth including loading/error handling.
class AuthController extends AsyncNotifier<void> {
  late final AuthRepository _authRepository;

  @override
  FutureOr<void> build() {
    _authRepository = ref.watch(authRepositoryProvider);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    // 1. Sign in
    state = await AsyncValue.guard(() => _authRepository.signInWithEmailPassword(email, password));
    
    // 2. Force refresh of profile data upon successful login
    if (!state.hasError) {
      ref.invalidate(userProfileProvider);
    }
  }
  
  Future<void> logout() async {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() => _authRepository.signOut());
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});


