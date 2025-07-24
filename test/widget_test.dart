// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pri_app/main.dart';
import 'package:pri_app/features/routes/routes_menu_button.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(initialUrl: 'http://localhost:3002'));

    // Verify that the app title is shown
    expect(find.text('Artheris FlightControl'), findsOneWidget);
    
    // Verify that the routes menu button is present
    expect(find.byIcon(Icons.route), findsOneWidget);
    
    // You can add more specific tests for the routes menu functionality here
  });
  
  testWidgets('Routes menu test', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RoutesMenuScaffold(
          currentRoute: 'http://localhost:3002',
          onRouteSelected: (String route) {},
          child: const Center(child: Text('Test Content')),
        ),
      ),
    ));
    
    // Open the drawer
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    
    // Verify that the drawer is open
    expect(find.text('Rutas del Servidor'), findsOneWidget);
  });
}
