import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pri_app/core/sensors/sensor_service.dart';

class SensorDisplay extends StatefulWidget {
  const SensorDisplay({super.key});

  @override
  State<SensorDisplay> createState() => _SensorDisplayState();
}

class _SensorDisplayState extends State<SensorDisplay> {
  String _timeString() {
    final now = DateTime.now().toLocal();
    // Formato simple: HH:MM:SS.mmm
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$hh:$mm:$ss.$ms';
  }

  String _fmtNum(double? v, {int decimals = 2}) {
    if (v == null) return '—';
    return v.toStringAsFixed(decimals);
  }

  Widget _row(
    String label,
    String value, {
    int labelFlex = 2,
    int valueFlex = 3,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: valueFlex,
            child: Text(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  // Helper: run calibration and show SnackBar safely (checks mounted)
  Future<void> _doCalibrate(BuildContext context) async {
    final sensorService = Provider.of<SensorService>(context, listen: false);
    // Optionally show immediate feedback
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Calibration started...')));
    try {
      await sensorService.calibrateZero();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Calibrated: new zero set')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Calibration failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the SensorService instance
    final sensorService = Provider.of<SensorService>(context, listen: true);

    final dateTimeStr = _timeString();

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.sensors),
                const SizedBox(width: 8),
                const Text(
                  'Sensor Readings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  dateTimeStr,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Divider(),

            // Estimated angles (from filter)
            _row('angleRollEst (°):', _fmtNum(sensorService.angleRollEst)),
            _row('anglePitchEst (°):', _fmtNum(sensorService.anglePitchEst)),

            const SizedBox(height: 8),
            // Orientation (fused)
            _row('Roll (°):', _fmtNum(sensorService.roll)),
            _row('Pitch (°):', _fmtNum(sensorService.pitch)),
            _row('Yaw (°):', _fmtNum(sensorService.yaw)),

            const SizedBox(height: 8),
            // Gyro rates (°/s)
            _row('gyroRoll (°/s):', _fmtNum(sensorService.gyroRoll)),
            _row('gyroPitch (°/s):', _fmtNum(sensorService.gyroPitch)),
            _row('gyroYaw (°/s):', _fmtNum(sensorService.gyroYaw)),

            const SizedBox(height: 8),
            // Accelerometer
            _row('accX:', _fmtNum(sensorService.accX)),
            _row('accY:', _fmtNum(sensorService.accY)),
            _row('accZ:', _fmtNum(sensorService.accZ)),

            const SizedBox(height: 12),
            // Buttons: Calibrate and Reset
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text('Calibrate (Set 0)'),
                    onPressed: () => _doCalibrate(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Filters'),
                    onPressed: () {
                      sensorService.resetFilters();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Filters reset')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
