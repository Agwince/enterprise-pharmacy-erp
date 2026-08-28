import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'ai_copilot_sheet.dart';
import '../screens/ceo_fleet_map_screen.dart';

enum DeviceViewMode {
  desktop,
  mobile,
}

class ExecutivePresentationShell extends StatefulWidget {
  final Widget child;

  const ExecutivePresentationShell({super.key, required this.child});

  @override
  State<ExecutivePresentationShell> createState() => _ExecutivePresentationShellState();
}

class _ExecutivePresentationShellState extends State<ExecutivePresentationShell> {
  DeviceViewMode _viewMode = DeviceViewMode.desktop;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNativeMobile = screenWidth < 700;

    // If opened on an actual mobile device, render natively without the frame
    if (isNativeMobile) {
      return widget.child;
    }

    final auth = AuthService();
    final currentRoleName = _getRoleDisplayName(auth.role);
    final currentRoleIcon = _getRoleIcon(auth.role);

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: Column(
          children: [
            // Executive Top Control Bar
            _buildExecutiveBar(context, auth, currentRoleName, currentRoleIcon),

            // Main View Area (Desktop or Simulated Phone)
            Expanded(
              child: _viewMode == DeviceViewMode.desktop
                  ? widget.child
                  : _buildMobileSimulator(widget.child),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveBar(
    BuildContext context,
    AuthService auth,
    String roleName,
    IconData roleIcon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Brand & Active Role
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enterprise Pharmacy ERP',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Executive Demo Mode (Kenya HQ)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Active Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(roleIcon, size: 14, color: Colors.tealAccent),
                const SizedBox(width: 6),
                Text(
                  roleName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Device Mode Switcher (Desktop vs Mobile)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDeviceTab(
                  mode: DeviceViewMode.desktop,
                  icon: Icons.laptop_chromebook_rounded,
                  label: 'Desktop ERP',
                ),
                const SizedBox(width: 4),
                _buildDeviceTab(
                  mode: DeviceViewMode.mobile,
                  icon: Icons.phone_iphone_rounded,
                  label: 'Mobile Runner View',
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Instant Role Switcher Dropdown
          PopupMenuButton<String>(
            tooltip: 'Switch Department Workspace',
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            onSelected: (choice) {
              _handleRoleSwitch(choice, context);
            },
            itemBuilder: (context) => [
              _buildMenuItem('ceo', Icons.insights_rounded, '👑 CEO Executive Analytics', Colors.tealAccent),
              _buildMenuItem('fleet', Icons.map_rounded, '🗺️ CEO Live Fleet Map', Colors.blueAccent),
              _buildMenuItem('manager', Icons.storefront_rounded, '🏪 Branch Manager Workspace', Colors.amberAccent),
              _buildMenuItem('telesales', Icons.point_of_sale_rounded, '💊 Telesales POS / Dispensing', Colors.pinkAccent),
              _buildMenuItem('picker', Icons.checklist_rounded, '📦 Warehouse Visual Pick-List', Colors.cyanAccent),
              _buildMenuItem('storekeeper', Icons.qr_code_scanner_rounded, '🔍 Storekeeper Stock Scanner', Colors.orangeAccent),
              _buildMenuItem('rider', Icons.two_wheeler_rounded, '🛵 Rider Logistics & Dispatch', Colors.deepOrangeAccent),
              _buildMenuItem('hr', Icons.badge_rounded, '👥 HR & Operations Workspace', Colors.purpleAccent),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF1E40AF)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.tealAccent.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Switch Department',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // AI Copilot Quick Launcher
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.tealAccent, size: 18),
            ),
            tooltip: 'Launch AI Copilot Advisor',
            onPressed: () => AiCopilotSheet.show(context),
          ),

          const SizedBox(width: 8),

          // Exit / Logout Button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            tooltip: 'Logout to Login Screen',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String val, IconData icon, String title, Color color) {
    return PopupMenuItem<String>(
      value: val,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _handleRoleSwitch(String choice, BuildContext context) {
    final auth = AuthService();
    switch (choice) {
      case 'ceo':
        auth.loginAsCeo();
        break;
      case 'fleet':
        auth.loginAsCeo();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CeoFleetMapScreen()),
        );
        break;
      case 'manager':
        auth.loginAsBranchManager();
        break;
      case 'telesales':
        auth.loginAsTelesales();
        break;
      case 'picker':
        auth.loginAsWarehousePicker();
        break;
      case 'storekeeper':
        auth.loginAsStorekeeper();
        break;
      case 'rider':
        auth.loginAsRider();
        break;
      case 'hr':
        auth.loginAsHr();
        break;
    }
  }

  Widget _buildDeviceTab({
    required DeviceViewMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.tealAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSimulator(Widget child) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        width: 390,
        height: 800,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(48),
          border: Border.all(
            color: const Color(0xFF334155),
            width: 8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 40,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: Colors.tealAccent.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            children: [
              // Screen Content
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(top: 36),
                  child: child,
                ),
              ),

              // Realistic Phone Status Bar & Dynamic Island
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 38,
                child: Container(
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '09:41',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      // Dynamic Island Pill
                      Container(
                        width: 90,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.tealAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ERP RUNNER',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.wifi, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Icon(Icons.battery_5_bar_rounded, size: 16, color: Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Home Indicator Bar
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 120,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.ceo:
        return 'Eleanor Vance (CEO)';
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.branchManager:
        return 'Sarah Jenkins (Branch Manager)';
      case UserRole.telesales:
        return 'Telesales POS';
      case UserRole.warehousePicker:
        return 'Dave Bowman (Warehouse Picker)';
      case UserRole.storekeeper:
        return 'Sam Wilson (Storekeeper)';
      case UserRole.rider:
        return 'Motorbike Rider (Dispatch)';
      case UserRole.hr:
        return 'Jessica Taylor (HR)';
      case UserRole.secretary:
        return 'Finance Secretary';
      case UserRole.catalogAdmin:
        return 'Jane Doe (Catalog Admin)';
      case UserRole.marketer:
        return 'Field Marketer';
      default:
        return 'Guest User';
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.ceo:
        return Icons.insights_rounded;
      case UserRole.superAdmin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.branchManager:
        return Icons.storefront_rounded;
      case UserRole.telesales:
        return Icons.point_of_sale_rounded;
      case UserRole.warehousePicker:
        return Icons.checklist_rounded;
      case UserRole.storekeeper:
        return Icons.qr_code_scanner_rounded;
      case UserRole.rider:
        return Icons.two_wheeler_rounded;
      case UserRole.hr:
        return Icons.badge_rounded;
      case UserRole.secretary:
        return Icons.account_balance_wallet_rounded;
      case UserRole.catalogAdmin:
        return Icons.inventory_2_rounded;
      case UserRole.marketer:
        return Icons.location_on_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}
