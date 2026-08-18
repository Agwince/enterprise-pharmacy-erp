import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole {
  none,
  superAdmin,
  ceo,
  hr,
  warehousePicker,
  storekeeper,
  catalogAdmin,
  branchManager,
  telesales,
  secretary,
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

  void loginAsSuperAdmin() {
    _role = UserRole.superAdmin;
    _userEmail = 'superadmin@pharmasaas.com';
    _userName = 'Super Admin (Platform Owner)';
    notifyListeners();
  }

  void loginAsCeo() {
    _role = UserRole.ceo;
    _userEmail = 'ceo@nairobibulk.com';
    _userName = 'Eleanor Vance (Client CEO)';
    notifyListeners();
  }

  void loginAsHr() {
    _role = UserRole.hr;
    _userEmail = 'hr@nairobibulk.com';
    _userName = 'Jessica Taylor (Client HR)';
    notifyListeners();
  }

  void loginAsWarehousePicker() {
    _role = UserRole.warehousePicker;
    _userEmail = 'picker@nairobibulk.com';
    _userName = 'Dave Bowman (Warehouse Picker)';
    notifyListeners();
  }

  void loginAsStorekeeper() {
    _role = UserRole.storekeeper;
    _userEmail = 'storekeeper@nairobibulk.com';
    _userName = 'Sam Wilson (Storekeeper)';
    notifyListeners();
  }

  void loginAsCatalogAdmin() {
    _role = UserRole.catalogAdmin;
    _userEmail = 'catalog@nairobibulk.com';
    _userName = 'Jane Doe (Catalog Admin)';
    notifyListeners();
  }

  void loginAsBranchManager() {
    _role = UserRole.branchManager;
    _userEmail = 'manager@nairobibulk.com';
    _userName = 'Sarah Jenkins (Branch Manager)';
    notifyListeners();
  }

  void loginAsTelesales() {
    _role = UserRole.telesales;
    _userEmail = 'telesales@pharmacy.com';
    _userName = 'Telesales Agent';
    notifyListeners();
  }

  void loginAsSecretary() {
    _role = UserRole.secretary;
    _userEmail = 'secretary@pharmacy.com';
    _userName = 'Finance Secretary';
    notifyListeners();
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        try {
          final res = await Supabase.instance.client.from('roles').select('role').eq('email', email).maybeSingle();
          if (res != null) {
            String dbRole = res['role'].toString().toUpperCase();
            if (dbRole == 'TELESALES') {
               loginAsTelesales();
               return true;
            } else if (dbRole == 'SECRETARY') {
               loginAsSecretary();
               return true;
            }
          }
        } catch (e) {
          debugPrint('Could not fetch custom role: $e');
        }

        if (email.contains('super') || email.contains('admin')) {
          loginAsSuperAdmin();
        } else if (email.contains('hr')) {
          loginAsHr();
        } else if (email.contains('picker') || email.contains('store')) {
          loginAsWarehousePicker();
        } else if (email.contains('manager')) {
          loginAsBranchManager();
        } else {
          loginAsCeo();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Supabase Auth note: $e');
    }

    // Demo fallback role parsing
    if (email.contains('super')) {
      loginAsSuperAdmin();
    } else if (email.contains('hr')) {
      loginAsHr();
    } else if (email.contains('picker')) {
      loginAsWarehousePicker();
    } else if (email.contains('manager')) {
      loginAsBranchManager();
    } else {
      loginAsCeo();
    }
    return true;
  }

  Future<void> logout() async {
    _role = UserRole.none;
    _userEmail = '';
    _userName = '';
    notifyListeners();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }
}
