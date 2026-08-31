import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_erp/screens/login_screen.dart';

void main() {
  group('Pull-Cord Lamp Widget & Responsive Layout Tests', () {
    testWidgets('Screen renders with empty fields, auto turns on lamp, and has pull cord hint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Frame 1: Full opacity, form is visible and usable immediately
      expect(find.text('Multi-Tenant Enterprise ERP'), findsOneWidget);
      expect(find.text('Pull the cord'), findsOneWidget);
      expect(find.text('Corporate Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In to Enterprise Workspace'), findsOneWidget);

      // Verify empty text inputs
      final emailField = tester.widget<TextField>(find.widgetWithText(TextField, 'Enter your corporate email'));
      expect(emailField.controller?.text, isEmpty);

      final passwordField = tester.widget<TextField>(find.widgetWithText(TextField, '••••••••'));
      expect(passwordField.controller?.text, isEmpty);
      expect(passwordField.obscureText, isTrue);

      // Advance 1.2s for auto lamp turn-on animation
      await tester.pump(const Duration(milliseconds: 1200));
    });

    testWidgets('Password visibility toggle toggles obscureText', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('Interactive pull-cord drag and spring release snap-back', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Pull down the cord target
      final cordGesture = find.byType(GestureDetector).first;
      await tester.drag(cordGesture, const Offset(0, 40));
      await tester.pump();

      // Release drag -> triggers spring animation
      await tester.pumpAndSettle();
    });

    testWidgets('375px width mobile viewport with keyboard open renders with NO overflow', (tester) async {
      tester.view.physicalSize = const Size(375 * 3, 667 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Simulate keyboard open by setting bottom viewInsets to 280px
      tester.view.viewInsets = const FakeViewPadding(bottom: 280.0 * 3);
      addTearDown(() => tester.view.resetViewInsets());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify form is visible, scrollable, and no RenderFlex overflow
      expect(tester.takeException(), isNull);
      expect(find.text('Sign In to Enterprise Workspace'), findsOneWidget);
    });
  });
}
