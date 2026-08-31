import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_admin.dart';
import '../services/branch_service.dart';

class BranchManagementScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const BranchManagementScreen({super.key, this.isSuperAdmin = true});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final BranchService _branchService = BranchService();
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTab = 0; // 0 = Branches, 1 = Audit Trail

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool _isAuthorized() {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email;
    return email != null && email.toLowerCase() == AppAdmin.rootEmail.toLowerCase();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final branches = await _branchService.getBranches();
      final logs = await _branchService.getAuditLogs();
      if (mounted) {
        setState(() {
          _branches = branches;
          _auditLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showCreateBranchDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final countyCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final managerCtrl = TextEditingController();
    bool isActive = true;
    bool isPosDefault = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_business_rounded, color: Colors.amberAccent),
              ),
              const SizedBox(width: 12),
              Text('Create New Branch', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Branch Code * (e.g. KTL-05)'),
                  _textField(codeCtrl, hint: 'e.g. KTL-05', isCaps: true),
                  const SizedBox(height: 12),
                  _fieldLabel('Branch Name *'),
                  _textField(nameCtrl, hint: 'e.g. Kitale Wholesale Hub'),
                  const SizedBox(height: 12),
                  _fieldLabel('County'),
                  _textField(countyCtrl, hint: 'e.g. Trans-Nzoia'),
                  const SizedBox(height: 12),
                  _fieldLabel('Physical Address'),
                  _textField(addressCtrl, hint: 'e.g. Kenyatta Street, Kitale CBD'),
                  const SizedBox(height: 12),
                  _fieldLabel('Contact Phone'),
                  _textField(phoneCtrl, hint: 'e.g. +254 700 000 000'),
                  const SizedBox(height: 12),
                  _fieldLabel('Branch Manager Name'),
                  _textField(managerCtrl, hint: 'e.g. Jane Doe'),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Active Branch Status', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('Inactive branches are hidden from transaction pickers', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                    value: isActive,
                    activeThumbColor: Colors.amberAccent,
                    onChanged: (val) => setModalState(() => isActive = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text('Set as POS Default Branch', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('Default branch for direct walk-in point-of-sale transactions', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                    value: isPosDefault,
                    activeThumbColor: Colors.amberAccent,
                    onChanged: (val) => setModalState(() => isPosDefault = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Branch Code and Name are required!'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }

                try {
                  await _branchService.createBranch(
                    code: codeCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                    county: countyCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    managerName: managerCtrl.text.trim(),
                    isActive: isActive,
                    isPosDefault: isPosDefault,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Branch ${codeCtrl.text.trim().toUpperCase()} created and verified in database!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text('Create Branch', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBranchDialog(Map<String, dynamic> branch) {
    final codeCtrl = TextEditingController(text: branch['code']?.toString() ?? '');
    final nameCtrl = TextEditingController(text: branch['name']?.toString() ?? '');
    final countyCtrl = TextEditingController(text: branch['county']?.toString() ?? '');
    final addressCtrl = TextEditingController(text: branch['address']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: branch['phone']?.toString() ?? '');
    final managerCtrl = TextEditingController(text: branch['manager_name']?.toString() ?? '');
    bool isActive = branch['is_active'] == true;
    bool isPosDefault = branch['is_pos_default'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              Text('Edit Branch Details', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.vpn_key_rounded, size: 14, color: Colors.white38),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'UUID: ${branch['id']} (Immutable)',
                            style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel('Branch Code *'),
                  _textField(codeCtrl, hint: 'e.g. NBO-01', isCaps: true),
                  const SizedBox(height: 12),
                  _fieldLabel('Branch Name *'),
                  _textField(nameCtrl, hint: 'e.g. Nairobi Central Hub'),
                  const SizedBox(height: 12),
                  _fieldLabel('County'),
                  _textField(countyCtrl, hint: 'e.g. Nairobi'),
                  const SizedBox(height: 12),
                  _fieldLabel('Physical Address'),
                  _textField(addressCtrl, hint: 'e.g. Industrial Area, Road A'),
                  const SizedBox(height: 12),
                  _fieldLabel('Contact Phone'),
                  _textField(phoneCtrl, hint: 'e.g. +254 700 000 000'),
                  const SizedBox(height: 12),
                  _fieldLabel('Branch Manager Name'),
                  _textField(managerCtrl, hint: 'e.g. John Doe'),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Active Branch Status', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('Inactive branches are preserved in history but hidden from new orders', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                    value: isActive,
                    activeThumbColor: Colors.amberAccent,
                    onChanged: (val) => setModalState(() => isActive = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text('Set as POS Default Branch', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('Default branch for walk-in POS billing', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                    value: isPosDefault,
                    activeThumbColor: Colors.amberAccent,
                    onChanged: (val) => setModalState(() => isPosDefault = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Branch Code and Name cannot be empty!'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }

                try {
                  await _branchService.updateBranch(
                    branch['id'].toString(),
                    {
                      'code': codeCtrl.text.trim(),
                      'name': nameCtrl.text.trim(),
                      'county': countyCtrl.text.trim().isEmpty ? null : countyCtrl.text.trim(),
                      'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      'manager_name': managerCtrl.text.trim().isEmpty ? null : managerCtrl.text.trim(),
                      'is_active': isActive,
                      'is_pos_default': isPosDefault,
                    },
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Branch ${codeCtrl.text.trim().toUpperCase()} updated & verified!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Update Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text('Save Changes', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationPickerDialog(Map<String, dynamic> branch) {
    final branchId = branch['id'].toString();
    final branchCode = (branch['code'] ?? '').toString().toUpperCase();
    final branchName = (branch['name'] ?? '').toString();

    final initialLat = (branch['latitude'] as num?)?.toDouble();
    final initialLng = (branch['longitude'] as num?)?.toDouble();

    LatLng? selectedPoint = (initialLat != null && initialLng != null)
        ? LatLng(initialLat, initialLng)
        : null;

    final latCtrl = TextEditingController(
        text: selectedPoint != null ? selectedPoint.latitude.toStringAsFixed(6) : '');
    final lngCtrl = TextEditingController(
        text: selectedPoint != null ? selectedPoint.longitude.toStringAsFixed(6) : '');

    final mapController = MapController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final center = selectedPoint ?? const LatLng(-1.2921, 36.8219);
          final double initialZoom = selectedPoint != null ? 14.0 : 6.5;

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pin_drop_rounded, color: Colors.tealAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Set Location on Map',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('$branchCode • $branchName',
                          style: GoogleFonts.inter(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_rounded, color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap anywhere on the map to place/move the pin, or enter coordinates below.',
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Map Container
                    Container(
                      height: 320,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          mapController: mapController,
                          options: MapOptions(
                            initialCenter: center,
                            initialZoom: initialZoom,
                            minZoom: 3.0,
                            maxZoom: 19.0,
                            onTap: (tapPosition, point) {
                              setModalState(() {
                                selectedPoint = point;
                                latCtrl.text = point.latitude.toStringAsFixed(6);
                                lngCtrl.text = point.longitude.toStringAsFixed(6);
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.yourcompany.pharmacyerp',
                              maxZoom: 19,
                            ),
                            if (selectedPoint != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: selectedPoint!,
                                    width: 54,
                                    height: 54,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.tealAccent),
                                          ),
                                          child: Text(
                                            branchCode,
                                            style: GoogleFonts.jetBrainsMono(
                                              color: Colors.tealAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.location_on,
                                          color: Colors.amberAccent,
                                          size: 28,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Manual Coordinate Inputs (Fallback)
                    Text('Manual Coordinate Fallback:',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Latitude (e.g. -1.292100)'),
                              const SizedBox(height: 4),
                              TextField(
                                controller: latCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: '-1.292100',
                                  hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 12),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                ),
                                onChanged: (val) {
                                  final lat = double.tryParse(val.trim());
                                  final lng = double.tryParse(lngCtrl.text.trim());
                                  if (lat != null && lng != null) {
                                    setModalState(() {
                                      selectedPoint = LatLng(lat, lng);
                                      mapController.move(selectedPoint!, 14.0);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Longitude (e.g. 36.821900)'),
                              const SizedBox(height: 4),
                              TextField(
                                controller: lngCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: '36.821900',
                                  hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 12),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                ),
                                onChanged: (val) {
                                  final lng = double.tryParse(val.trim());
                                  final lat = double.tryParse(latCtrl.text.trim());
                                  if (lat != null && lng != null) {
                                    setModalState(() {
                                      selectedPoint = LatLng(lat, lng);
                                      mapController.move(selectedPoint!, 14.0);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
              ),
              if (selectedPoint != null)
                TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await _branchService.updateBranch(branchId, {
                        'latitude': null,
                        'longitude': null,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadData();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Coordinates cleared for $branchCode.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                  child: Text('Clear Location', style: GoogleFonts.inter(color: Colors.redAccent)),
                ),
              ElevatedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final lat = double.tryParse(latCtrl.text.trim());
                  final lng = double.tryParse(lngCtrl.text.trim());

                  if (lat == null || lng == null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Please tap the map to drop a pin or enter valid numeric coordinates.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Coordinates out of range (Lat: -90..90, Lng: -180..180).'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  try {
                    await _branchService.setBranchLocation(
                      branchId,
                      latitude: lat,
                      longitude: lng,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadData();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Location saved for $branchCode: (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text('Save Location', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteBranchDialog(Map<String, dynamic> branch) async {
    final branchId = branch['id'].toString();
    final branchCode = (branch['code'] ?? '').toString().toUpperCase();
    final branchName = (branch['name'] ?? '').toString();
    final isPosDefault = branch['is_pos_default'] == true;

    // 1. Check POS default
    if (isPosDefault) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.amberAccent, size: 24),
              const SizedBox(width: 12),
              Text('POS Default Branch Protected', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            'This is the point-of-sale default branch ($branchCode - $branchName). Change the default in settings before deleting it.',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              child: Text('Understood', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Fetch dependencies
    final deps = await _branchService.countBranchDependencies(branchId);
    final int totalDeps = deps['total'] ?? 0;

    if (!mounted) return;

    if (totalDeps > 0) {
      // Deletion Blocked -> Offer Deactivation
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.amberAccent, size: 24),
              const SizedBox(width: 12),
              Text('Deletion Blocked — Historical Data Exists', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Branch $branchCode ($branchName) has $totalDeps linked database records and cannot be permanently deleted without causing data loss:',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    _depRow('Sales Transactions', deps['transactions'] ?? 0),
                    _depRow('Staff Records', deps['staff'] ?? 0),
                    _depRow('Requisitions (In/Out)', deps['requisitions'] ?? 0),
                    _depRow('Payroll Runs', deps['payroll'] ?? 0),
                    _depRow('Inventory Batches', deps['stock'] ?? 0),
                    _depRow('User Accounts', deps['users'] ?? 0),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Recommended Action: Deactivate the branch. It will disappear from transaction pickers while preserving all transaction history. Deactivating is completely reversible.',
                style: GoogleFonts.inter(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await _branchService.deactivateBranch(branchId);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Branch $branchCode deactivated safely.'), backgroundColor: Colors.orange),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
              icon: const Icon(Icons.pause_circle_rounded, size: 18),
              label: Text('Deactivate Branch', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      // 0 Dependencies -> Allow Permanent Delete with confirmation code input
      final confirmCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 24),
                const SizedBox(width: 12),
                Text('Permanent Branch Deletion', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Branch $branchCode ($branchName) has 0 linked records and can be deleted.',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))),
                    child: Text(
                      'WARNING: This action cannot be undone. All configuration for this branch will be permanently erased.',
                      style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Type the branch code "$branchCode" to confirm:', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmCtrl,
                    style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: branchCode,
                      hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent)),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
              ),
              ElevatedButton.icon(
                onPressed: confirmCtrl.text.trim().toUpperCase() == branchCode
                    ? () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _branchService.deleteBranch(branchId, confirmCtrl.text.trim());
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadData();
                          messenger.showSnackBar(
                            SnackBar(content: Text('Branch $branchCode permanently deleted.'), backgroundColor: Colors.redAccent),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Delete failed: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: Text('Permanently Delete', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _depRow(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
          Text('$count', style: GoogleFonts.jetBrainsMono(color: count > 0 ? Colors.amberAccent : Colors.white38, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(text, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600));
  }

  Widget _textField(TextEditingController ctrl, {required String hint, bool isCaps = false}) {
    return TextField(
      controller: ctrl,
      textCapitalization: isCaps ? TextCapitalization.characters : TextCapitalization.words,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSuperAdmin && !_isAuthorized()) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: Text('Branch Governance', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: const Color(0xFF1E293B),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text('Access Denied', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Branch management is restricted strictly to the Super Admin platform owner.', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.apartment_rounded, color: Colors.amberAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Branch Network Governance', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                Text('Super Admin Control Panel • Multi-Branch Configuration', style: GoogleFonts.inter(fontSize: 10, color: Colors.amberAccent)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : Column(
              children: [
                Container(
                  color: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _tabButton(0, 'Active Branches (${_branches.length})', Icons.business_rounded),
                      const SizedBox(width: 12),
                      _tabButton(1, 'Audit Trail Logs (${_auditLogs.length})', Icons.history_rounded),
                      const Spacer(),
                      if (_selectedTab == 0)
                        ElevatedButton.icon(
                          onPressed: _showCreateBranchDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text('Create Branch', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    padding: const EdgeInsets.all(12),
                    child: Text('Notice: $_errorMessage', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                  ),
                Expanded(
                  child: _selectedTab == 0 ? _buildBranchesView() : _buildAuditLogsView(),
                ),
              ],
            ),
    );
  }

  Widget _tabButton(int index, String label, IconData icon) {
    final isSel = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSel ? Colors.amberAccent : Colors.transparent, width: 2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSel ? Colors.amberAccent : Colors.white54),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(color: isSel ? Colors.white : Colors.white54, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchesView() {
    if (_branches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_mall_directory_outlined, size: 48, color: Colors.white30),
            const SizedBox(height: 12),
            Text('No branches registered', style: GoogleFonts.inter(color: Colors.white70, fontSize: 15)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                dataTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                columns: const [
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Branch Name')),
                  DataColumn(label: Text('County')),
                  DataColumn(label: Text('Manager')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Coordinates / Location')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('POS Default')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _branches.map((b) {
                  final bool active = b['is_active'] == true;
                  final bool isDefault = b['is_pos_default'] == true;
                  final lat = (b['latitude'] as num?)?.toDouble();
                  final lng = (b['longitude'] as num?)?.toDouble();
                  final bool hasCoords = lat != null && lng != null;

                  return DataRow(
                    cells: [
                      DataCell(Text(b['code']?.toString() ?? '', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: Colors.amberAccent))),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(b['name']?.toString() ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            if (b['address'] != null)
                              Text(b['address'].toString(), style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      DataCell(Text(b['county']?.toString() ?? '—', style: GoogleFonts.inter(color: Colors.white70))),
                      DataCell(Text(b['manager_name']?.toString() ?? '—', style: GoogleFonts.inter(color: Colors.white70))),
                      DataCell(Text(b['phone']?.toString() ?? '—', style: GoogleFonts.inter(color: Colors.white70))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasCoords)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.tealAccent, size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                                      style: GoogleFonts.jetBrainsMono(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Coordinates not set',
                                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _showLocationPickerDialog(b),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: hasCoords ? Colors.tealAccent : Colors.amberAccent,
                                side: BorderSide(
                                  color: hasCoords
                                      ? Colors.tealAccent.withValues(alpha: 0.5)
                                      : Colors.amberAccent.withValues(alpha: 0.5),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 28),
                              ),
                              icon: Icon(
                                hasCoords ? Icons.edit_location_alt_rounded : Icons.add_location_alt_rounded,
                                size: 14,
                              ),
                              label: Text(
                                hasCoords ? 'Edit Location' : 'Set location on map',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: active ? Colors.greenAccent.withValues(alpha: 0.15) : Colors.orangeAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            active ? 'Active' : 'Inactive',
                            style: GoogleFonts.inter(color: active ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      DataCell(
                        isDefault
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                child: Text('POS Default', style: GoogleFonts.inter(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                              )
                            : TextButton(
                                onPressed: () async {
                                  await _branchService.setDefaultPosBranch(b['id'].toString());
                                  _loadData();
                                },
                                child: Text('Set Default', style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 11)),
                              ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 18),
                              onPressed: () => _showEditBranchDialog(b),
                              tooltip: 'Edit Branch',
                            ),
                            IconButton(
                              icon: Icon(
                                active ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                                color: active ? Colors.orangeAccent : Colors.greenAccent,
                                size: 18,
                              ),
                              onPressed: () async {
                                if (active) {
                                  await _branchService.deactivateBranch(b['id'].toString());
                                } else {
                                  await _branchService.reactivateBranch(b['id'].toString());
                                }
                                _loadData();
                              },
                              tooltip: active ? 'Deactivate Branch' : 'Reactivate Branch',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                              onPressed: () => _showDeleteBranchDialog(b),
                              tooltip: 'Delete Branch',
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsView() {
    if (_auditLogs.isEmpty) {
      return Center(
        child: Text('No branch audit logs recorded yet.', style: GoogleFonts.inter(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        final action = log['action']?.toString() ?? 'ACTION';
        final code = log['branch_code']?.toString() ?? 'BRANCH';
        final performedBy = log['performed_by']?.toString() ?? 'Admin';
        final createdAt = log['created_at'] != null ? DateTime.tryParse(log['created_at'].toString()) : null;

        Color badgeColor = Colors.blueAccent;
        if (action == 'CREATED') badgeColor = Colors.greenAccent;
        if (action == 'DELETED') badgeColor = Colors.redAccent;
        if (action == 'DEACTIVATED') badgeColor = Colors.orangeAccent;
        if (action == 'REACTIVATED') badgeColor = Colors.tealAccent;

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(action, style: GoogleFonts.jetBrainsMono(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            title: Text('Branch $code • Performed by $performedBy', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
              createdAt != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt.toLocal()) : '',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
            ),
          ),
        );
      },
    );
  }
}