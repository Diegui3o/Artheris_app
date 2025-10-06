import 'dart:async';

class Calibrator {
  // Parámetros (puedes ajustarlos si quieres replicar otra configuración)
  final int buffersize;
  final int acel_deadzone;
  final int giro_deadzone;
  final int delayMs;

  // Variables internas que replican tu sketch
  int ax_offset = 0, ay_offset = 0, az_offset = 0;
  int gx_offset = 0, gy_offset = 0, gz_offset = 0;

  int mean_ax = 0,
      mean_ay = 0,
      mean_az = 0,
      mean_gx = 0,
      mean_gy = 0,
      mean_gz = 0;

  Calibrator({
    this.buffersize = 1000,
    this.acel_deadzone = 8,
    this.giro_deadzone = 1,
    this.delayMs = 2,
  });

  Future<Map<String, int>> calibrateSensors(
    Future<List<int>> Function() sampleProvider,
  ) async {
    // Inicializar offsets a 0 (como en tu sketch)
    ax_offset = 0;
    ay_offset = 0;
    az_offset = 0;
    gx_offset = 0;
    gy_offset = 0;
    gz_offset = 0;

    // mean sensors (igual que meansensors())
    await _meanSensors(sampleProvider);

    // calcular offsets iniciales (igual a calibration() antes del while)
    ax_offset = (-mean_ax / 8).round();
    ay_offset = (-mean_ay / 8).round();
    az_offset = ((16384 - mean_az) / 8).round();

    gx_offset = (-mean_gx / 4).round();
    gy_offset = (-mean_gy / 4).round();
    gz_offset = (-mean_gz / 4).round();

    // Bucle iterativo (igual que el while(1) en calibration())
    while (true) {
      int ready = 0;

      await _meanSensors(sampleProvider);

      // Verificaciones y ajustes (idéntico a tu sketch)
      if (mean_ax.abs() <= acel_deadzone) {
        ready++;
      } else {
        ax_offset = ax_offset - (mean_ax / acel_deadzone).round();
      }

      if (mean_ay.abs() <= acel_deadzone) {
        ready++;
      } else {
        ay_offset = ay_offset - (mean_ay / acel_deadzone).round();
      }

      if ((16384 - mean_az).abs() <= acel_deadzone) {
        ready++;
      } else {
        az_offset = az_offset + ((16384 - mean_az) / acel_deadzone).round();
      }

      if (mean_gx.abs() <= giro_deadzone) {
        ready++;
      } else {
        gx_offset = gx_offset - (mean_gx / (giro_deadzone + 1)).round();
      }

      if (mean_gy.abs() <= giro_deadzone) {
        ready++;
      } else {
        gy_offset = gy_offset - (mean_gy / (giro_deadzone + 1)).round();
      }

      if (mean_gz.abs() <= giro_deadzone) {
        ready++;
      } else {
        gz_offset = gz_offset - (mean_gz / (giro_deadzone + 1)).round();
      }

      // Si todas las 6 condiciones cumplen, salimos (ready == 6)
      if (ready == 6) break;
      // de otra forma, se repite el bucle (como en Arduino)
    }

    // Devuelve los offsets como enteros (tal como usarías en setXGyroOffset)
    return {
      'ax_offset': ax_offset,
      'ay_offset': ay_offset,
      'az_offset': az_offset,
      'gx_offset': gx_offset,
      'gy_offset': gy_offset,
      'gz_offset': gz_offset,
    };
  }

  Future<void> _meanSensors(Future<List<int>> Function() sampleProvider) async {
    int i = 0;
    // acumuladores en 64-bit para evitar overflow
    int buffAx = 0, buffAy = 0, buffAz = 0, buffGx = 0, buffGy = 0, buffGz = 0;

    final int total = buffersize + 101;
    while (i < total) {
      // Pedimos una muestra cruda: [ax, ay, az, gx, gy, gz]
      final sample = await sampleProvider();
      if (sample.length < 6) {
        throw Exception('sampleProvider must return 6 ints: ax,ay,az,gx,gy,gz');
      }
      int ax = sample[0];
      int ay = sample[1];
      int az = sample[2];
      int gx = sample[3];
      int gy = sample[4];
      int gz = sample[5];

      // Igual que en Arduino: solo acumula entre i=101 .. i=buffersize+100
      if (i > 100 && i <= (buffersize + 100)) {
        buffAx += ax;
        buffAy += ay;
        buffAz += az;
        buffGx += gx;
        buffGy += gy;
        buffGz += gz;
      }

      i++;
      // delay(2) en Arduino
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    // medias (enteros, igual que el sketch)
    mean_ax = (buffAx / buffersize).round();
    mean_ay = (buffAy / buffersize).round();
    mean_az = (buffAz / buffersize).round();
    mean_gx = (buffGx / buffersize).round();
    mean_gy = (buffGy / buffersize).round();
    mean_gz = (buffGz / buffersize).round();
  }
}
