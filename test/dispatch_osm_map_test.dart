import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('OpenStreetMap TileLayer & MarkerLayer render properly in FlutterMap', (WidgetTester tester) async {
    const kisumuPos = LatLng(-0.0917, 34.7680);
    const nairobiPos = LatLng(-1.2921, 36.8219);

    // 1. Mobile viewport 375x812
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(-0.5, 35.8),
              initialZoom: 7.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourcompany.pharmacyerp',
                maxZoom: 19,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(points: [kisumuPos, nairobiPos], color: Colors.tealAccent, strokeWidth: 3.0),
                ],
              ),
              const MarkerLayer(
                markers: [
                  Marker(
                    point: kisumuPos,
                    width: 40,
                    height: 40,
                    child: Icon(Icons.local_shipping, color: Colors.orange, size: 36),
                  ),
                  Marker(
                    point: nairobiPos,
                    width: 40,
                    height: 40,
                    child: Icon(Icons.location_pin, color: Colors.red, size: 36),
                  ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify FlutterMap, TileLayer, PolylineLayer, MarkerLayer, and Attribution
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping), findsOneWidget);
    expect(find.byIcon(Icons.location_pin), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsWidgets);

    // 2. Desktop viewport 1440x900
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
  });
}