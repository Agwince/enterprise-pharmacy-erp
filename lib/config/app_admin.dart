class AppAdmin {
  static const String rootEmail = 'admin@pharmacy.com';

  /// Returns true if the account is immutable root admin or executive role (SUPER_ADMIN, CEO)
  static bool isImmutableAdmin(String? email, String? role) {
    if (email == null && role == null) return false;
    final normalizedEmail = email?.trim().toLowerCase() ?? '';
    final normalizedRole = role?.trim().toUpperCase() ?? '';

    if (normalizedEmail == rootEmail.toLowerCase()) return true;
    if (normalizedRole == 'SUPER_ADMIN' ||
        normalizedRole == 'SUPERADMIN' ||
        normalizedRole == 'CEO' ||
        normalizedRole == 'ADMIN') {
      return true;
    }
    return false;
  }
}