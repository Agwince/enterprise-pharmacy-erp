import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DispatchMapScreen extends StatefulWidget {
  final LatLng? destination;
  final String? destinationName;

  const DispatchMapScreen({
    super.key,
    this.destination,
    this.destinationName,
  });

  @override
  State<DispatchMapScreen> createState() => _DispatchMapScreenState();
}

class _DispatchMapScreenState extends State<DispatchMapScreen> {
  final MapController _mapController = MapController();
  final List<Map<String, dynamic>> _riderLocations = [];
  RealtimeChannel? _subscription;
  bool _isLoading = true;

  // Nairobi default center (-1.2921, 36.8219)
  static const LatLng _nairobiCenter = LatLng(-1.2921, 36.8219);
  // Kisumu Bulk Hub center (-0.0917, 34.7680)
  static const LatLng _kisumuHub = LatLng(-0.0917, 34.7680);

  LatLng? _selectedRiderPos;
  String? _selectedRiderName;
  String? _selectedRiderVehicle;
  DateTime? _selectedRiderLastSeen;

  @override
  void initState() {
    super.initState();
    _fetchInitialLocations();
    _subscribeToRiderLocations();
  }

  Future<void> _fetchInitialLocations() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('rider_locations')
          .select()
          .order('updated_at', ascending: false);

      final List<Map<String, dynamic>> list =
          List<Map<String, dynamic>>.from(res as List);

      if (mounted) {
        setState(() {
          _riderLocations.clear();
          _riderLocations.addAll(list);
          if (_riderLocations.isNotEmpty) {
            final first = _riderLocations.first;
            final lat = (first['lat'] as num?)?.toDouble();
            final lng = (first['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              _selectedRiderPos = LatLng(lat, lng);
              _selectedRiderName =
                  first['rider_name']?.toString() ?? 'Active Courier';
              _selectedRiderVehicle =
                  first['vehicle_plate']?.toString() ?? 'KDC 482J';
              _selectedRiderLastSeen = first['updated_at'] != null
                  ? DateTime.tryParse(first['updated_at'].toString())
                  : null;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching rider locations: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToRiderLocations() {
    _subscription = Supabase.instance.client
        .channel('public:rider_locations_osm')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rider_locations',
          callback: (payload) {
            final location = payload.newRecord;
            if (location.isNotEmpty && mounted) {
              final id = location['id']?.toString();
              setState(() {
                _riderLocations.removeWhere((r) => r['id']?.toString() == id);
                _riderLocations.insert(0, location);

                final lat = (location['lat'] as num?)?.toDouble();
                final lng = (location['lng'] as num?)?.toDouble();
                if (lat != null && lng != null) {
                  _selectedRiderPos = LatLng(lat, lng);
                  _selectedRiderName =
                      location['rider_name']?.toString() ?? 'Active Courier';
                  _selectedRiderVehicle =
                      location['vehicle_plate']?.toString() ?? 'KDC 482J';
                  _selectedRiderLastSeen = location['updated_at'] != null
                      ? DateTime.tryParse(location['updated_at'].toString())
                      : DateTime.now();
                }
              });
            }
          },
        )
        .subscribe();
  }

  double? _computeStraightLineDistanceKm(LatLng p1, LatLng p2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, p1, p2);
  }

  Future<void> _launchNativeNavigation(LatLng dest) async {
    final geoUri = Uri.parse(
        'geo:${dest.latitude},${dest.longitude}?q=${dest.latitude},${dest.longitude}');
    final osmUri = Uri.parse(
        'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=${_selectedRiderPos?.latitude ?? _nairobiCenter.latitude},${_selectedRiderPos?.longitude ?? _nairobiCenter.longitude};${dest.latitude},${dest.longitude}');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
      } else {
        await launchUrl(osmUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Navigation launch note: $e');
    }
  }

  @override
  void dispose() {
    if (_subscription != null) {
      Supabase.instance.client.removeChannel(_subscription!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LatLng dest = widget.destination ?? _kisumuHub;
    final String destName =
        widget.destinationName ?? 'Kisumu Bulk Hub (KSM-02)';

    final double? straightLineDist = _selectedRiderPos != null
        ? _computeStraightLineDistanceKm(_selectedRiderPos!, dest)
        : null;

    final List<Marker> markers = [];

    // Destination Marker
    markers.add(
      Marker(
        point: dest,
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
          ),
          child: const Icon(Icons.location_pin, color: Colors.white, size: 26),
        ),
      ),
    );

    // Rider Marker (Rendered only if real coordinates exist)
    if (_selectedRiderPos != null) {
      markers.add(
        Marker(
          point: _selectedRiderPos!,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
            ),
            child: const Icon(Icons.local_shipping,
                color: Colors.white, size: 24),
          ),
        ),
      );
    }

    final List<Polyline> polylines = [];
    if (_selectedRiderPos != null) {
      polylines.add(
        Polyline(
          points: [_selectedRiderPos!, dest],
          color: Colors.tealAccent,
          strokeWidth: 3.0,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.map_rounded,
                  color: Colors.tealAccent, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Fleet Dispatch Map',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white),
                ),
                Text(
                  'OpenStreetMap • Keyless & Free Navigation',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white60),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.my_location_rounded, color: Colors.tealAccent),
            tooltip: 'Center on Vehicle',
            onPressed: () {
              if (_selectedRiderPos != null) {
                _mapController.move(_selectedRiderPos!, 13.0);
              } else {
                _mapController.move(_nairobiCenter, 12.0);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchInitialLocations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent))
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedRiderPos ?? _nairobiCenter,
                    initialZoom: 12.0,
                    minZoom: 3.0,
                    maxZoom: 19.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.yourcompany.pharmacyerp',
                      maxZoom: 19,
                    ),
                    if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                    MarkerLayer(markers: markers),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          '© OpenStreetMap contributors',
                          onTap: () => launchUrl(
                              Uri.parse('https://openstreetmap.org/copyright')),
                        ),
                      ],
                    ),
                  ],
                ),

                // Top Info Banner
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.tealAccent.withValues(alpha: 0.4)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 8)
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedRiderPos != null
                              ? Icons.satellite_alt_rounded
                              : Icons
                                  .signal_cellular_connected_no_internet_0_bar_rounded,
                          color: _selectedRiderPos != null
                              ? Colors.tealAccent
                              : Colors.amberAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedRiderPos != null
                                    ? '${_selectedRiderVehicle ?? "Vehicle"} (${_selectedRiderName ?? "Courier"})'
                                    : 'Awaiting live GPS telemetry signal',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                              if (_selectedRiderPos != null &&
                                  straightLineDist != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Straight-line distance to $destName: ${straightLineDist.toStringAsFixed(1)} km',
                                      style: GoogleFonts.inter(
                                          color: Colors.white70, fontSize: 11),
                                    ),
                                    if (_selectedRiderLastSeen != null)
                                      Text(
                                        'Last GPS beacon: ${_selectedRiderLastSeen!.hour.toString().padLeft(2, "0")}:${_selectedRiderLastSeen!.minute.toString().padLeft(2, "0")}',
                                        style: GoogleFonts.inter(
                                            color: Colors.tealAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500),
                                      ),
                                  ],
                                )
                              else
                                Text(
                                  'No active GPS fix. Awaiting courier device beacon.',
                                  style: GoogleFonts.inter(
                                      color: Colors.white54, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                        if (_selectedRiderPos != null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _launchNativeNavigation(dest),
                            icon:
                                const Icon(Icons.navigation_rounded, size: 16),
                            label: Text('Navigate',
                                style: GoogleFonts.inter(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
