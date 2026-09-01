import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/glass_container.dart';

class CeoFleetMapScreen extends StatefulWidget {
  const CeoFleetMapScreen({super.key});

  @override
  State<CeoFleetMapScreen> createState() => _CeoFleetMapScreenState();
}

class _CeoFleetMapScreenState extends State<CeoFleetMapScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _fleet = [];
  bool _isLoading = true;
  int _selectedVehicleIndex = 0;
  bool _showMap = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _fetchFleet();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchFleet() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('fleet_vehicles')
          .select('*, profiles:assigned_marketer_id(full_name)')
          .order('last_updated', ascending: false);

      final list = res as List<dynamic>;
      if (list.isNotEmpty) {
        if (mounted) {
          setState(() {
            _fleet = List<Map<String, dynamic>>.from(list);
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _fleet = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF070D18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isDesktop ? 'Live Telematics & Fleet Dispatch' : 'Fleet Dispatch Radar',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: isDesktop ? 16 : 14, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Kenya National Logistics Grid • Real-time GPS',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.tealAccent),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // View Mode Switcher
          IconButton(
            tooltip: _showMap ? 'Switch to Fleet List' : 'Switch to Radar Map',
            icon: Icon(_showMap ? Icons.list_alt_rounded : Icons.map_rounded, color: Colors.tealAccent),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchFleet,
            tooltip: 'Ping Fleet Satellites',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : Column(
              children: [
                // Top Logistics Telemetry Ribbon
                _buildLogisticsRibbon(),

                // Main Fleet Map or List
                Expanded(
                  child: _showMap
                      ? (isDesktop ? _buildDesktopMapLayout() : _buildMobileMapLayout())
                      : _buildFleetListView(),
                ),
              ],
            ),
    );
  }

  Widget _buildLogisticsRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStatItem('Active Units', '${_fleet.length}', Icons.two_wheeler_rounded, Colors.tealAccent),
            const SizedBox(width: 24),
            _buildStatItem('Telemetry Nodes', _fleet.isEmpty ? '0 Online' : '${_fleet.length} Connected', Icons.wifi_tethering_rounded, Colors.cyanAccent),
            const SizedBox(width: 24),
            _buildStatItem('Live Stream', _fleet.isEmpty ? 'Idle' : 'Active GPS', Icons.satellite_alt_rounded, const Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
            Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopMapLayout() {
    final selectedVehicle = (_fleet.isNotEmpty && _selectedVehicleIndex < _fleet.length)
        ? _fleet[_selectedVehicleIndex]
        : null;

    return Row(
      children: [
        // Interactive Radar Map
        Expanded(
          flex: 7,
          child: _buildInteractiveRadarMap(),
        ),

        // Telemetry Details Sidebar
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border(
                left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: selectedVehicle != null
                ? _buildVehicleTelemetryCard(selectedVehicle)
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.two_wheeler_outlined, size: 48, color: Colors.white24),
                          const SizedBox(height: 12),
                          Text(
                            'No Fleet In Transit',
                            style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active fleet telemetry and live GPS routes will stream here in real-time.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileMapLayout() {
    final selectedVehicle = (_fleet.isNotEmpty && _selectedVehicleIndex < _fleet.length)
        ? _fleet[_selectedVehicleIndex]
        : null;

    return Column(
      children: [
        Expanded(
          flex: 6,
          child: _buildInteractiveRadarMap(),
        ),
        if (selectedVehicle != null)
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: _buildVehicleTelemetryCard(selectedVehicle),
            ),
          ),
      ],
    );
  }

  Widget _buildInteractiveRadarMap() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          children: [
            // Dark Cartographic Background Grid
            Positioned.fill(
              child: CustomPaint(
                painter: KenyaMapPainter(
                  pulseValue: _pulseController.value,
                  vehicles: _fleet,
                  selectedIndex: _selectedVehicleIndex,
                ),
              ),
            ),

            // Interactive Clickable Vehicle Markers
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: _fleet.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final v = entry.value;
                      final isSelected = idx == _selectedVehicleIndex;

                      // Map GPS coordinates to canvas coordinates (Kenya bounding box)
                      final lat = (v['current_lat'] as num?)?.toDouble() ?? -1.28;
                      final lng = (v['current_lng'] as num?)?.toDouble() ?? 36.82;

                      // Kenya bounds: Lat [-4.7 to 4.5], Lng [33.9 to 41.9]
                      final normX = ((lng - 33.5) / (41.5 - 33.5)).clamp(0.1, 0.9);
                      final normY = ((4.2 - lat) / (4.2 - (-4.7))).clamp(0.1, 0.9);

                      final posX = normX * constraints.maxWidth;
                      final posY = normY * constraints.maxHeight;

                      final isBike = v['is_bike'] == true || (v['vehicle_model']?.toString().contains('Motorbike') ?? false);

                      return Positioned(
                        left: posX - 24,
                        top: posY - 24,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedVehicleIndex = idx);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: isSelected ? 48 : 36,
                                height: isSelected ? 48 : 36,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.tealAccent : const Color(0xFF1E293B),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.tealAccent,
                                    width: isSelected ? 3 : 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isSelected ? Colors.tealAccent : Colors.cyanAccent).withValues(alpha: 0.5),
                                      blurRadius: isSelected ? 20 : 10,
                                      spreadRadius: isSelected ? 4 : 1,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isBike ? Icons.two_wheeler_rounded : Icons.local_shipping_rounded,
                                  size: isSelected ? 24 : 18,
                                  color: isSelected ? Colors.black : Colors.tealAccent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white24, width: 0.5),
                                ),
                                child: Text(
                                  v['plate_number'] ?? 'Rider',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

            if (_fleet.isEmpty)
              Center(
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.radar_rounded, color: Colors.tealAccent, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Radar Scanning • 0 Active Fleet En Route',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

            // Top-left GPS Coordinate Readout
            Positioned(
              top: 16,
              left: 16,
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      'KENYA LOGISTICS MESH • 4 HUBS ONLINE',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVehicleTelemetryCard(Map<String, dynamic> v) {
    final plate = v['plate_number']?.toString() ?? 'Unregistered Plate';
    final model = v['vehicle_model']?.toString() ?? 'Fleet Vehicle';
    final isBike = v['is_bike'] == true || model.toLowerCase().contains('motorbike') || model.toLowerCase().contains('bike');
    final driver = v['profiles']?['full_name']?.toString() ?? v['driver_name']?.toString() ?? v['assigned_marketer']?.toString() ?? 'Unassigned Rider';
    final destination = v['destination']?.toString() ?? 'Not specified';
    final speed = v['speed']?.toString() ?? (v['speed_kmh'] != null ? '${v['speed_kmh']} km/h' : '--');
    final temp = v['temp']?.toString() ?? (v['temp_celsius'] != null ? '${v['temp_celsius']}°C' : '--');
    final status = (v['status']?.toString() ?? 'ACTIVE').toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  isBike ? Icons.two_wheeler_rounded : Icons.local_shipping_rounded,
                  color: Colors.tealAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plate,
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      model,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // Telematics Grid
          Text('LIVE TELEMETRY SENSORS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.tealAccent, letterSpacing: 1)),
          const SizedBox(height: 12),

          _buildTelemetryRow('Assigned Driver', driver, Icons.person_rounded),
          _buildTelemetryRow('Live Speed', speed, Icons.speed_rounded),
          _buildTelemetryRow('Cargo Temperature', temp, Icons.thermostat_rounded, valueColor: Colors.cyanAccent),
          _buildTelemetryRow('Delivery Target', destination, Icons.local_hospital_rounded, valueColor: Colors.amberAccent),
          _buildTelemetryRow('GPS Coordinates', '${v['current_lat'] ?? '--'}, ${v['current_lng'] ?? '--'}', Icons.gps_fixed_rounded),

          const SizedBox(height: 24),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.teal,
                    content: Text('Satellite ping sent to $plate. Telemetry refreshed.', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Ping Vehicle Sensor', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow(String title, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 10),
          Text(title, style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _fleet.length,
      itemBuilder: (context, index) {
        final v = _fleet[index];
        return GlassContainer(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.tealAccent.withValues(alpha: 0.15),
              child: const Icon(Icons.two_wheeler_rounded, color: Colors.tealAccent),
            ),
            title: Text(v['plate_number'] ?? 'Vehicle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text(v['vehicle_model'] ?? 'Model', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
            trailing: Text(
              '${v['current_lat']}, ${v['current_lng']}',
              style: GoogleFonts.inter(color: Colors.tealAccent, fontSize: 11),
            ),
          ),
        );
      },
    );
  }
}

// Custom High-End Vector Painter for Kenya Logistics Radar
class KenyaMapPainter extends CustomPainter {
  final double pulseValue;
  final List<Map<String, dynamic>> vehicles;
  final int selectedIndex;

  KenyaMapPainter({
    required this.pulseValue,
    required this.vehicles,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF070E1C);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Subtle Tactical Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Hub Coordinates (Normalized within canvas)
    final hubs = [
      {'name': 'Nairobi Central HQ', 'pos': Offset(size.width * 0.48, size.height * 0.62)},
      {'name': 'Kisumu Bulk Hub', 'pos': Offset(size.width * 0.22, size.height * 0.48)},
      {'name': 'Mombasa Coastal Depot', 'pos': Offset(size.width * 0.78, size.height * 0.85)},
      {'name': 'Eldoret Transit Hub', 'pos': Offset(size.width * 0.28, size.height * 0.38)},
    ];

    // Draw Transit Corridor Lines
    final routePaint = Paint()
      ..color = Colors.tealAccent.withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final nairobi = hubs[0]['pos'] as Offset;
    final kisumu = hubs[1]['pos'] as Offset;
    final mombasa = hubs[2]['pos'] as Offset;
    final eldoret = hubs[3]['pos'] as Offset;

    canvas.drawLine(nairobi, kisumu, routePaint);
    canvas.drawLine(nairobi, mombasa, routePaint);
    canvas.drawLine(nairobi, eldoret, routePaint);
    canvas.drawLine(eldoret, kisumu, routePaint);

    // Draw Hub Markers with glowing rings
    for (var hub in hubs) {
      final pos = hub['pos'] as Offset;

      // Outer radar pulse
      final pulsePaint = Paint()
        ..color = Colors.tealAccent.withValues(alpha: (1.0 - pulseValue) * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(pos, 14 + (pulseValue * 20), pulsePaint);

      // Hub core
      final corePaint = Paint()..color = Colors.tealAccent;
      canvas.drawCircle(pos, 6, corePaint);

      // Hub text
      final textPainter = TextPainter(
        text: TextSpan(
          text: hub['name'] as String,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pos.dx - (textPainter.width / 2), pos.dy + 10));
    }
  }

  @override
  bool shouldRepaint(covariant KenyaMapPainter oldDelegate) => true;
}
