import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pri_app/core/sensors/sensor_service.dart';
import 'core/camera/camera_service.dart';
import 'features/home/home_page.dart';
import 'features/routes/routes_menu.dart';
import 'routes/server_url.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Store the original debugPrint
  final originalDebugPrint = debugPrint;
  // Override debugPrint to add a prefix
  debugPrint = (String? message, {int? wrapWidth}) {
    originalDebugPrint('DEBUG: $message', wrapWidth: wrapWidth);
  };

  try {
    // Initialize ServerUrlManager
    final urlManager = ServerUrlManager();
    final initialUrl = await urlManager.getServerUrl();
    
    // Initialize and start sensor service
    final sensorService = SensorService();
    debugPrint('Initializing SensorService...');
    
    try {
      sensorService.startListening();
      debugPrint('SensorService started successfully');
    } catch (e) {
      debugPrint('Failed to start SensorService: $e');
      // Continue anyway, the UI will show no data
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SensorService>.value(
            value: sensorService,
          ),
          Provider<CameraService>(
            create: (context) => CameraService(),
            lazy: false,
          ),
          Provider<ServerUrlManager>.value(value: urlManager),
        ],
        child: MyApp(initialUrl: initialUrl),
      ),
    );
  } catch (e) {
    debugPrint('Fatal error in main(): $e');
    // Show error UI
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Failed to initialize app: $e'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  final String initialUrl;

  const MyApp({super.key, required this.initialUrl});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  late String _currentUrl;
  late ServerUrlManager _urlManager;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _urlManager = ServerUrlManager();
  }

  Future<void> _handleUrlChange(String newUrl) async {
    await _urlManager.setServerUrl(newUrl);
    setState(() {
      _currentUrl = newUrl;
    });

    // Opcional: Mostrar un mensaje de confirmación
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ruta actualizada: $newUrl')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Artheris',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Artheris FlightControl'),
            actions: [
              Builder(
                builder: (innerContext) => IconButton(
                  icon: const Icon(Icons.route),
                  tooltip: 'Cambiar ruta del servidor',
                  onPressed: () {
                    Scaffold.of(innerContext).openEndDrawer();
                  },
                ),
              ),
            ],
          ),
          endDrawer: Drawer(
            child: RoutesMenu(
              currentRoute: _currentUrl,
              onRouteSelected: _handleUrlChange,
            ),
          ),
          body: const MyHomePage(title: 'Artheris FlightControl'),
        ),
      ),
    );
  }
}
