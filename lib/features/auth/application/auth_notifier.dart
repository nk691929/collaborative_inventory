import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../../core/models.dart';
import 'auth_service.dart';

class AuthNotifier extends StateNotifier<AppUser?> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(_authService.initialize());

//login
  Future<void> login(String email, String password) async {
    try {
      final user = await _authService.login(email, password);
      state = user;
    } catch (e) {
      rethrow;
    }
  }

//logout
  Future<void> logout() async {
    await _authService.logout();
    state = null;
  }
}

//authServiceProvider
final authServiceProvider = Provider<AuthService>((ref) {
  final sessionBox = Hive.box<AppUser>('sessionBox');
  return AuthService(sessionBox);
});

//authProvider
final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});


//permissionProvider
final permissionProvider = Provider.family<bool, AppRole>((ref, requiredRole) {
  final user = ref.watch(authProvider);
  return ref.watch(authServiceProvider).hasPermission(user, requiredRole);
});
