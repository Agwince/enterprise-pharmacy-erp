import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';

class MarketerDashboardScreen extends StatefulWidget {
  const MarketerDashboardScreen({super.key});

  @override
  State<MarketerDashboardScreen> createState() => _MarketerDashboardScreenState();
}

class _MarketerDashboardScreenState extends State<MarketerDashboardScreen> {
  final _clientNameController = TextEditingController();
  Map<String, dynamic>? _myVehicle;
  bool _isLoadingVehicle = true;
  bool _isCheckingIn = false;

  @override
  void initState() {
    super.initState();
    _fetchMyVehicle();
  }

  Future<void> _fetchMyVehicle() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final res = await Supabase.instance.client
          .from('fleet_vehicles')
          .select()
          .eq('assigned_marketer_id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _myVehicle = res;
          _isLoadingVehicle = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVehicle = false;
        });
      }
    }
  }

  Future<void> _checkInClient() async {
    final clientName = _clientNameController.text.trim();
    if (clientName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a client name'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isCheckingIn = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Simulate capturing GPS (e.g. random nearby coordinates in Nairobi)
      final double simulatedLat = -1.2921 + (DateTime.now().second % 10) * 0.001;
      final double simulatedLng = 36.8219 + (DateTime.now().minute % 10) * 0.001;

      // 1. Insert Visit
      await Supabase.instance.client.from('marketer_visits').insert({
        'marketer_id': user.id,
        'client_name': clientName,
        'visit_lat': simulatedLat,
        'visit_lng': simulatedLng,
        'status': 'Visited',
      });

      // 2. Update Vehicle Location
      if (_myVehicle != null) {
        await Supabase.instance.client.from('fleet_vehicles').update({
          'current_lat': simulatedLat,
          'current_lng': simulatedLng,
          'last_updated': DateTime.now().toIso8601String(),
        }).eq('id', _myVehicle!['id']);
      }

      if (mounted) {
        _clientNameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Visit Logged & Fleet Tracking Updated', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ));
      }
      
      // Refresh vehicle data
      await _fetchMyVehicle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error checking in: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Marketer Portal', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => AuthService().logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fleet Tracking', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _isLoadingVehicle 
                ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                : _myVehicle == null
                    ? GlassContainer(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.directions_car, color: Colors.white54, size: 32),
                              const SizedBox(width: 16),
                              Text('No vehicle assigned to you.', style: GoogleFonts.inter(color: Colors.white54)),
                            ],
                          ),
                        ),
                      )
                    : GlassContainer(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_car, color: Colors.tealAccent, size: 32),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('My Assigned Vehicle', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                          Text('${_myVehicle!['vehicle_model'] ?? 'Unknown'} - ${_myVehicle!['plate_number'] ?? 'N/A'}', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: Text('Active', style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(color: Colors.white.withOpacity(0.1)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Current GPS Lat', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                      Text('${_myVehicle!['current_lat'] ?? 'Unknown'}', style: GoogleFonts.inter(color: Colors.white)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Current GPS Lng', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                      Text('${_myVehicle!['current_lng'] ?? 'Unknown'}', style: GoogleFonts.inter(color: Colors.white)),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
              const SizedBox(height: 32),
              Text('Log Client Visit', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GlassContainer(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _clientNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Client / Clinic Name',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.3),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.person, color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isCheckingIn ? null : _checkInClient,
                          icon: _isCheckingIn ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Icon(Icons.location_on),
                          label: Text(_isCheckingIn ? 'Checking In...' : 'Check-In (Capture GPS)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
