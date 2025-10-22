import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/models.dart';

class AuthService {
  final Box<AppUser> _sessionBox;

  AuthService(this._sessionBox);
  
  static const _mockUsers = {
    'admin@example.com': AppRole.admin,
    'manager@example.com': AppRole.manager,
    'viewer@example.com': AppRole.viewer,
  };
  
  AppUser? initialize() {
    return _sessionBox.get('currentUser');
  }

  Future<AppUser?> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500)); 

    final role = _mockUsers[email];

    if (role != null && password.isNotEmpty) {
      final user = AppUser(
        id: const Uuid().v4(),
        email: email,
        role: role,
      );
      
      await _sessionBox.put('currentUser', user);
      debugPrint('Login success: ${user.email} as ${user.role.name}');
      return user;
    }
    
    throw Exception('Invalid credentials or user role not found.');
  }

  Future<void> logout() async {
    await _sessionBox.delete('currentUser');
    debugPrint('User logged out.');
  }
  
  bool hasPermission(AppUser? user, AppRole requiredRole) {
    if (user == null) {
      return false;
    }
    
    return user.role.index <= requiredRole.index;
  }
}
