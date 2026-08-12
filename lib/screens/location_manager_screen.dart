import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class LocationManagerScreen extends StatelessWidget {
  const LocationManagerScreen({super.key});

  void _showAuditSnackbar(BuildContext context, String medicineName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Audit triggered for $medicineName. Stock count request sent to floor team.',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                const Icon(
                  Icons.warehouse_rounded,
                  color: Colors.tealAccent,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Manager — Digital Twin',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Branch: Nairobi Central',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary Banner
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Colors.tealAccent, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(2), // For gradient border effect
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.tealAccent),
                    const SizedBox(width: 12),
                    Text(
                      '3 Aisles Mapped • 8 Shelves • 10 SKUs Registered',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Aisle 1
            _buildAisle(
              context,
              'Aisle 1 - General Medicines',
              '3 Shelves',
              [
                _buildShelf(
                  context,
                  'Shelf A',
                  [
                    _buildItem(context, 'Amoxicillin 500mg', '50 Cartons'),
                    _buildItem(context, 'Paracetamol 500mg', '120 Cartons'),
                  ],
                ),
                _buildShelf(
                  context,
                  'Shelf B',
                  [
                    _buildItem(context, 'Ibuprofen 400mg', '35 Cartons'),
                    _buildItem(context, 'Metformin 500mg', '80 Cartons'),
                  ],
                ),
                _buildShelf(
                  context,
                  'Shelf C',
                  [
                    _buildItem(context, 'Omeprazole 20mg', '45 Cartons'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Aisle 2
            _buildAisle(
              context,
              'Aisle 2 - Antibiotics & Antivirals',
              '2 Shelves',
              [
                _buildShelf(
                  context,
                  'Shelf A',
                  [
                    _buildItem(context, 'Azithromycin 250mg', '25 Cartons'),
                    _buildItem(context, 'Ciprofloxacin 500mg', '60 Cartons'),
                  ],
                ),
                _buildShelf(
                  context,
                  'Shelf B',
                  [
                    _buildItem(context, 'Acyclovir 200mg', '40 Cartons'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Aisle 3
            _buildAisle(
              context,
              'Aisle 3 - Cold Storage (2-8°C)',
              '2 Shelves',
              [
                _buildShelf(
                  context,
                  'Shelf A',
                  [
                    _buildItem(context, 'Insulin Glargine', '15 Vials'),
                    _buildItem(context, 'Hepatitis B Vaccine', '30 Doses'),
                  ],
                ),
                _buildShelf(
                  context,
                  'Shelf B',
                  [
                    _buildItem(context, 'COVID-19 Pfizer Vaccine', '50 Doses'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAisle(BuildContext context, String title, String subtitle, List<Widget> children) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.view_column_rounded, color: Colors.tealAccent),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        trailing: Text(
          subtitle,
          style: GoogleFonts.inter(
            color: Colors.grey[400],
          ),
        ),
        iconColor: Colors.tealAccent,
        collapsedIconColor: Colors.grey[400],
        children: children,
      ),
    );
  }

  Widget _buildShelf(BuildContext context, String title, List<Widget> items) {
    return Container(
      color: const Color(0xFF283548), // Slightly lighter background
      child: ExpansionTile(
        leading: const Icon(Icons.shelves, color: Colors.tealAccent),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconColor: Colors.tealAccent,
        collapsedIconColor: Colors.grey[400],
        children: items,
      ),
    );
  }

  Widget _buildItem(BuildContext context, String name, String quantity) {
    return ListTile(
      leading: const Icon(Icons.medication_rounded, color: Colors.tealAccent),
      title: Text(
        name,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        quantity,
        style: GoogleFonts.inter(
          color: Colors.grey[400],
        ),
      ),
      trailing: OutlinedButton(
        onPressed: () => _showAuditSnackbar(context, name),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.orange),
          foregroundColor: Colors.orange,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: Size.zero,
        ),
        child: const Text('Audit'),
      ),
    );
  }
}
