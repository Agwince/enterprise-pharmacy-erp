import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LocationManagerScreen extends StatefulWidget {
  const LocationManagerScreen({super.key});

  @override
  State<LocationManagerScreen> createState() => _LocationManagerScreenState();
}

class _LocationManagerScreenState extends State<LocationManagerScreen> {
  final _aisleNameController = TextEditingController(text: 'Aisle 4');
  final _shelfCountController = TextEditingController(text: '5');
  String _selectedAisleType = 'General Medicines';

  final List<Map<String, dynamic>> _aisles = [
    {
      'title': 'Aisle 1 - General Medicines',
      'subtitle': '3 Shelves',
      'shelves': [
        {
          'title': 'Shelf A',
          'items': [
            {'name': 'Amoxicillin 500mg', 'qty': '50 Cartons'},
            {'name': 'Paracetamol 500mg', 'qty': '120 Cartons'},
          ]
        },
        {
          'title': 'Shelf B',
          'items': [
            {'name': 'Ibuprofen 400mg', 'qty': '35 Cartons'},
            {'name': 'Metformin 500mg', 'qty': '80 Cartons'},
          ]
        },
        {
          'title': 'Shelf C',
          'items': [
            {'name': 'Omeprazole 20mg', 'qty': '45 Cartons'},
          ]
        },
      ]
    },
    {
      'title': 'Aisle 2 - Antibiotics & Antivirals',
      'subtitle': '2 Shelves',
      'shelves': [
        {
          'title': 'Shelf A',
          'items': [
            {'name': 'Azithromycin 250mg', 'qty': '25 Cartons'},
            {'name': 'Ciprofloxacin 500mg', 'qty': '60 Cartons'},
          ]
        },
        {
          'title': 'Shelf B',
          'items': [
            {'name': 'Acyclovir 200mg', 'qty': '40 Cartons'},
          ]
        },
      ]
    },
    {
      'title': 'Aisle 3 - Cold Storage (2-8°C)',
      'subtitle': '2 Shelves',
      'shelves': [
        {
          'title': 'Shelf A',
          'items': [
            {'name': 'Insulin Glargine', 'qty': '15 Vials'},
            {'name': 'Hepatitis B Vaccine', 'qty': '30 Doses'},
          ]
        },
        {
          'title': 'Shelf B',
          'items': [
            {'name': 'COVID-19 Pfizer Vaccine', 'qty': '50 Doses'},
          ]
        },
      ]
    },
  ];

  void _generateDigitalShelves() {
    final aisleName = _aisleNameController.text.trim();
    final countText = _shelfCountController.text.trim();
    final count = int.tryParse(countText) ?? 3;

    if (aisleName.isEmpty || count <= 0) return;

    final alphabet = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
    final List<Map<String, dynamic>> generatedShelves = [];

    for (int i = 0; i < count; i++) {
      final shelfLetter = i < alphabet.length ? alphabet[i] : '${i + 1}';
      generatedShelves.add({
        'title': 'Shelf $shelfLetter',
        'items': [
          {'name': 'Unassigned SKU Slot ${i + 1}', 'qty': '0 Units (Ready for Putaway)'},
        ]
      });
    }

    setState(() {
      _aisles.insert(0, {
        'title': '$aisleName - $_selectedAisleType',
        'subtitle': '$count Digital Shelves Generated',
        'shelves': generatedShelves,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.tealAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Digital Map Generated: $count shelves created for $aisleName without physical scanning.',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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

  int get _totalShelves {
    int sum = 0;
    for (var a in _aisles) {
      sum += (a['shelves'] as List).length;
    }
    return sum;
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
                  size: 44,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Manager — Digital Twin',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Branch: Nairobi Central • Zero-Scan Setup Engine',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // DIGITAL BULK SHELF CREATOR CARD (TASK 1)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.grid_view_rounded, color: Colors.tealAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Digital Shelves (Bulk Setup)',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Instantly generate virtual aisle & shelf maps without scanning physical QR codes.',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Inputs Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      return isWide
                          ? Row(
                              children: [
                                Expanded(flex: 2, child: _buildAisleInput()),
                                const SizedBox(width: 12),
                                Expanded(flex: 2, child: _buildCategoryDropdown()),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: _buildCountInput()),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _generateDigitalShelves,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.tealAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.flash_on_rounded, size: 20),
                                  label: Text(
                                    'Generate Map',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildAisleInput(),
                                const SizedBox(height: 12),
                                _buildCategoryDropdown(),
                                const SizedBox(height: 12),
                                _buildCountInput(),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: _generateDigitalShelves,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.tealAccent,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.flash_on_rounded, size: 20),
                                    label: Text(
                                      'Generate Map',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Dynamic Summary Banner
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
                      '${_aisles.length} Aisles Mapped • $_totalShelves Shelves • Digital Twin Active',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Aisles & Shelves Hierarchy List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _aisles.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final aisle = _aisles[index];
                final shelves = aisle['shelves'] as List<Map<String, dynamic>>;

                return _buildAisle(
                  context,
                  aisle['title'],
                  aisle['subtitle'],
                  shelves.map((s) {
                    final items = s['items'] as List<Map<String, String>>;
                    return _buildShelf(
                      context,
                      s['title'],
                      items.map((item) => _buildItem(context, item['name']!, item['qty']!)).toList(),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAisleInput() {
    return TextField(
      controller: _aisleNameController,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Aisle Name / Number',
        labelStyle: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAisleType,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 'General Medicines', child: Text('General Medicines')),
            DropdownMenuItem(value: 'Antibiotics & Antivirals', child: Text('Antibiotics & Antivirals')),
            DropdownMenuItem(value: 'Cold Storage (2-8°C)', child: Text('Cold Storage (2-8°C)')),
            DropdownMenuItem(value: 'Pediatric Syrups', child: Text('Pediatric Syrups')),
            DropdownMenuItem(value: 'Surgical & Consumables', child: Text('Surgical & Consumables')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedAisleType = val);
          },
        ),
      ),
    );
  }

  Widget _buildCountInput() {
    return TextField(
      controller: _shelfCountController,
      keyboardType: TextInputType.number,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'No. of Shelves',
        labelStyle: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
      color: const Color(0xFF283548),
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
