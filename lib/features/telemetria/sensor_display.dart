import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pri_app/core/sensors/sensor_service.dart';

class SensorDisplay extends StatelessWidget {
  const SensorDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final sensorService = Provider.of<SensorService>(context, listen: false);
    return StreamBuilder<double>(
      stream: sensorService.rollStream,
      builder: (context, rollSnapshot) {
        return StreamBuilder<double>(
          stream: sensorService.pitchStream,
          builder: (context, pitchSnapshot) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Roll: ${rollSnapshot.data?.toStringAsFixed(2) ?? '0.00'}°', style: TextStyle(fontSize: 24)),
                Text('Pitch: ${pitchSnapshot.data?.toStringAsFixed(2) ?? '0.00'}°', style: TextStyle(fontSize: 24)),
              ],
            );
          },
        );
      },
    );
  }
}
