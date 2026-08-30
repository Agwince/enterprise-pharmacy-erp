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
  rider,
  marketer,
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

  void setUserSession({
    required UserRole role,
    required String email,
    required String name,
  }) {
    _role = role;
    _userEmail = email;
    _userName = name;
    notifyListeners();
  }

  void loginAsSuperAdmin({String email = '', String name = ''}) {
    _role = UserRole.superAdmin;
    _userEmail = email;
    _userName = name.isNotEmpty ? name : 'Platform Super Admin';
    notifyListeners();
  }

  void loginAsCeo({String email = '', String name = ''}) {
    _role = UserRole.ceo;
    _userEmail = email;
    _userName = name.isNotEmpty ? name : 'CEO';
    notifyListeners();
  }

  void loginAsHr({String email = '', String name = ''}) {
    _role = UserRole.hr;
    _userEmail = email;
    _userName = name.isNotEmpty ? name : 'HR Manager';
    notifyListeners();
  }

  void loginAsWarehousePicker({String email = '', String name = ''}) {
    _role = UserRole.warehousePicker;
    _userEmail = email;
    _userName = name.isNotEmpty ? name : 'Warehouse Picker';
    notifyListeners();
  }

  void loginAsStorekeeper({String email = '', String name = ''}) {
    _role = UserRole.storekeeper;
    _userEmail = email;
    _userName = name.isNotEmpty ? name : 'Storekeeper';
    notifyListeners();
  }

  void loginAsCatalogAdmin({String email = '', String name = ''}) {
    _role = UserRole.catalogAdmin;
    _userEmail = email;
    _userName = name.isNotEmpty ? name : 'Catalog Admin';
    notifyListeners();
  }

  void loginAsBranchManager({String email = '', String name = ''}) {
    _role = UserRole.branchManager;
    _userEmail = email;
    _userName = name.isNotEmpty ? name : 'Branch Manager';
    notifyListeners();
  }

  void loginAsTelesales({String email = '', String name = ''}) {
    _role = UserRole.telesales;
    _userEmail = email;
    _userName = name.isNotEmpty ? name : 'Telesales Agent';
    notifyListeners();
  }

  void loginAsSecretary({String email = '', String name = ''}) {
    _role = UserRole.secretary;
    _userEmail = email;
    _userName = name.isNotEmpty ? name : 'Finance Secretary';
    notifyListeners();
  }

  void loginAsRider({String email = '', String name = ''}) {
    _role = UserRole.rider;
    _userEmail = email;
    _userName = name.isNotEmpty ? name : 'Motorbike Rider';
    notifyListeners();
  }

  void loginAsMarketer({String email = '', String name = ''}) {
    _role = UserRole.marketer;
    _userEmail = email;
    _userName = name.isNotEmpty ? name : 'Field Marketer';
    notifyListeners();
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        final realEmail = response.user!.email ?? email;
        final res = await Supabase.instance.client
            .from('roles')
            .select('*')
            .eq('email', realEmail)
            .maybeSingle();

        if (res != null) {
          final String dbRole = res['role'].toString().toUpperCase();
          final String realName = (res['full_name'] ?? res['name'] ?? realEmail).toString();
          switch (dbRole) {
            case 'SUPER_ADMIN':
            case 'SUPERADMIN':
              loginAsSuperAdmin(email: realEmail, name: realName);
              return true;
            case 'CEO':
              loginAsCeo(email: realEmail, name: realName);
              return true;
            case 'HR':
              loginAsHr(email: realEmail, name: realName);
              return true;
            case 'WAREHOUSE_PICKER':
            case 'PICKER':
              loginAsWarehousePicker(email: realEmail, name: realName);
              return true;
            case 'STOREKEEPER':
              loginAsStorekeeper(email: realEmail, name: realName);
              return true;
            case 'CATALOG_ADMIN':
            case 'CATALOG':
              loginAsCatalogAdmin(email: realEmail, name: realName);
              return true;
            case 'BRANCH_MANAGER':
            case 'MANAGER':
              loginAsBranchManager(email: realEmail, name: realName);
              return true;
            case 'TELESALES':
              loginAsTelesales(email: realEmail, name: realName);
              return true;
            case 'SECRETARY':
              loginAsSecretary(email: realEmail, name: realName);
              return true;
            case 'RIDER':
              loginAsRider(email: realEmail, name: realName);
              return true;
            case 'MARKETER':
              loginAsMarketer(email: realEmail, name: realName);
              return true;
            default:
              debugPrint('Unknown role: $dbRole');
              return false;
          }
        }
        return false;
      }
    } catch (e) {
      debugPrint('Supabase Auth error: $e');
      rethrow;
    }
    return false;
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
