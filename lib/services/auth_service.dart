import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole {
  none,
  ceo,
  storekeeper,
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserRole _role = UserRole.none;
  String _userEmail = '';
  String _userName = '';

  UserRole get role => _role;
  String get userEmail => _userEmail;
  String get userName => _userName;
  bool get isAuthenticated => _role != UserRole.none;

  void loginAsCeo() {
    _role = UserRole.ceo;
    _userEmail = 'ceo@pharmacy.com';
    _userName = 'Eleanor Vance (CEO)';
    notifyListeners();
  }

  void loginAsStorekeeper() {
    _role = UserRole.storekeeper;
    _userEmail = 'storekeeper@pharmacy.com';
    _userName = 'Dave Bowman (Storekeeper)';
    notifyListeners();
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        // Simple role parsing based on email or default to CEO
        if (email.contains('store') || email.contains('pick') || email.contains('intake')) {
          loginAsStorekeeper();
        } else {
          loginAsCeo();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Supabase Auth error (falling back to quick demo mode): $e');
    }
    
    // Fallback demo authentication if offline or unseeded user
    if (email.contains('storekeeper')) {
      loginAsStorekeeper();
    } else {
      loginAsCeo();
    }
    return true;
  }

  void logout() {
    _role = UserRole.none;
    _userEmail = '';
    _userName = '';
    try {
      Supabase.instance.client.auth.signOut();
    } catch (_) {}
    notifyListeners();
  }
}
