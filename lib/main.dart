import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/sensors/sensor_service.dart';
import 'core/camera/camera_service.dart';
import 'features/home/home_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<SensorService>(
          create: (context) => SensorService()..startListening(),
          lazy: false,
        ),
        Provider<CameraService>(
          create: (context) => CameraService(),
          lazy: false,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Artheris',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Artheris FlightControl'),
    );
  }
}
