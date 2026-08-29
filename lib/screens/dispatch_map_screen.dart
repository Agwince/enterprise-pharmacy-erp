import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class DispatchMapScreen extends StatefulWidget {
  const DispatchMapScreen({super.key});

  @override
  State<DispatchMapScreen> createState() => _DispatchMapScreenState();
}

class _DispatchMapScreenState extends State<DispatchMapScreen> {
  final Set<Marker> _markers = {};
  RealtimeChannel? _subscription;
  
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(-1.2921, 36.8219), // Nairobi
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _fetchInitialLocations();
    _subscribeToRiderLocations();
  }

  Future<void> _fetchInitialLocations() async {
    try {
      final res = await Supabase.instance.client.from('rider_locations').select();
      for (var location in res) {
        _updateMarker(location);
      }
    } catch (e) {
      debugPrint('Error fetching initial locations: $e');
    }
  }

  void _subscribeToRiderLocations() {
    _subscription = Supabase.instance.client
        .channel('public:rider_locations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rider_locations',
          callback: (payload) {
            final location = payload.newRecord;
            if (location.isNotEmpty) {
              _updateMarker(location);
            }
          },
        )
        .subscribe();
  }

  void _updateMarker(Map<String, dynamic> location) {
    if (!mounted) return;
    
    final id = location['id'].toString();
    final name = location['rider_name'] as String? ?? 'Unknown Rider';
    final lat = (location['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (location['lng'] as num?)?.toDouble() ?? 0.0;

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == id);
      _markers.add(
        Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: name, snippet: 'Rider Active'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_subscription!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Dispatch Map', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GoogleMap(
        initialCameraPosition: _initialCamera,
        markers: _markers,
        myLocationEnabled: false,
        zoomControlsEnabled: true,
      ),
    );
  }
}
