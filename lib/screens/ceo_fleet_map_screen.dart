import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/glass_container.dart';
import '../widgets/ai_copilot_sheet.dart';

class CeoFleetMapScreen extends StatefulWidget {
  const CeoFleetMapScreen({super.key});

  @override
  State<CeoFleetMapScreen> createState() => _CeoFleetMapScreenState();
}

class _CeoFleetMapScreenState extends State<CeoFleetMapScreen> {
  List<Map<String, dynamic>> _fleet = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFleet();
  }

  Future<void> _fetchFleet() async {
    try {
      final res = await Supabase.instance.client
          .from('fleet_vehicles')
          .select('*, profiles:assigned_marketer_id(full_name)')
          .order('last_updated', ascending: false);

      if (mounted) {
        setState(() {
          _fleet = List<Map<String, dynamic>>.from(res as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Fallback if profiles join fails (e.g. no fk)
        try {
          final fallbackRes = await Supabase.instance.client
              .from('fleet_vehicles')
              .select()
              .order('last_updated', ascending: false);
              
          if (mounted) {
            setState(() {
              _fleet = List<Map<String, dynamic>>.from(fallbackRes as List);
              _isLoading = false;
            });
          }
        } catch (innerE) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading fleet: ${innerE.toString()}')));
            setState(() => _isLoading = false);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Inherits from parent shell or GradientScaffold
      floatingActionButton: FloatingActionButton(
        onPressed: () => AiCopilotSheet.show(context),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Live Fleet Tracking', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.tealAccent),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchFleet();
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
        : _fleet.isEmpty
            ? Center(child: Text('No active fleet vehicles found.', style: GoogleFonts.inter(color: Colors.white54)))
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _fleet.length,
                itemBuilder: (context, index) {
                  final vehicle = _fleet[index];
                  final marketerName = vehicle['profiles']?['full_name'] ?? 'Unknown Marketer';
                  
                  return GlassContainer(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.directions_car, color: Colors.tealAccent, size: 28),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(vehicle['plate_number'] ?? 'N/A', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                      Text(vehicle['vehicle_model'] ?? 'Unknown Model', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blueAccent),
                                ),
                                child: Text('Live GPS', style: GoogleFonts.inter(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.white54, size: 16),
                              const SizedBox(width: 8),
                              Text('Assigned to: $marketerName', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lat: ${vehicle['current_lat'] ?? 'N/A'}, Lng: ${vehicle['current_lng'] ?? 'N/A'}',
                                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.white54, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Last Updated: ${vehicle['last_updated'] != null ? DateTime.parse(vehicle['last_updated']).toLocal().toString().split('.')[0] : 'N/A'}', 
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
