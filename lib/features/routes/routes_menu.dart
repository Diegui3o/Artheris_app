import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoutesMenu extends StatefulWidget {
  final ValueChanged<String> onRouteSelected;
  final String currentRoute;
  
  const RoutesMenu({
    super.key,
    required this.onRouteSelected,
    required this.currentRoute,
  });

  @override
  _RoutesMenuState createState() => _RoutesMenuState();
}

class _RoutesMenuState extends State<RoutesMenu> {
  final List<String> _commonRoutes = [
    'http://192.168.1.11:3002',
    'http://localhost:3002',
    'http://10.0.2.2:3002', // Para emulador Android
  ];
  
  final _formKey = GlobalKey<FormState>();
  final _protocolController = TextEditingController(text: 'http://');
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '3002');
  
  List<String> _savedRoutes = [];
  bool _isLoading = true;

  // Expresión regular para validar direcciones IP
  final _ipRegex = RegExp(
    r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
  );

  @override
  void initState() {
    super.initState();
    _loadSavedRoutes();
  }

  @override
  void dispose() {
    _protocolController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedRoutes() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final savedRoutes = prefs.getStringList('saved_routes') ?? [];
    
    // Asegurarnos de que no hay duplicados con las rutas comunes
    final allRoutes = {..._commonRoutes, ...savedRoutes}.toList();
    
    setState(() {
      _savedRoutes = allRoutes;
      _isLoading = false;
    });
  }

  Future<void> _addNewRoute(String route) async {
    if (route.isEmpty) return;
    
    // Asegurarnos de que la URL tenga el esquema
    if (!route.startsWith('http://') && !route.startsWith('https://')) {
      route = 'http://$route';
    }
    
    final prefs = await SharedPreferences.getInstance();
    final savedRoutes = prefs.getStringList('saved_routes') ?? [];
    
    // Evitar duplicados
    if (!savedRoutes.contains(route)) {
      savedRoutes.add(route);
      await prefs.setStringList('saved_routes', savedRoutes);
      await _loadSavedRoutes();
    }
    
    widget.onRouteSelected(route);
    
    // Cerrar el diálogo
    if (mounted) {
      Navigator.of(context).pop();
    }
  }



  // Validador de IP
  String? _validateIp(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa una dirección IP';
    }
    if (!_ipRegex.hasMatch(value)) {
      return 'Ingresa una dirección IP válida';
    }
    return null;
  }

  // Validador de puerto
  String? _validatePort(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa un puerto';
    }
    final port = int.tryParse(value);
    if (port == null || port <= 0 || port > 65535) {
      return 'Puerto inválido (1-65535)';
    }
    return null;
  }

  void _showAddRouteDialog() {
    // Limpiar controladores al abrir el diálogo
    _ipController.clear();
    _portController.text = '3002';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir nueva ruta'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selector de protocolo
              DropdownButtonFormField<String>(
                value: 'http://',
                decoration: const InputDecoration(
                  labelText: 'Protocolo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'http://',
                    child: Text('http://'),
                  ),
                  DropdownMenuItem(
                    value: 'https://',
                    child: Text('https://'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _protocolController.text = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              // Campo para la dirección IP
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Dirección IP',
                  hintText: 'Ej: 192.168.1.100',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: _validateIp,
                onFieldSubmitted: (_) => _submitNewRoute(),
              ),
              const SizedBox(height: 16),
              // Campo para el puerto
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Puerto',
                  hintText: 'Ej: 3002',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: _validatePort,
                onFieldSubmitted: (_) => _submitNewRoute(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: _submitNewRoute,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitNewRoute() async {
    try {
      if (_formKey.currentState?.validate() ?? false) {
        final protocol = _protocolController.text;
        final ip = _ipController.text.trim();
        final port = _portController.text.trim();
        final url = '$protocol$ip:$port';
        
        // Validar la URL completa
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          throw const FormatException('La URL debe comenzar con http:// o https://');
        }
        
        await _addNewRoute(url);
        
        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ruta guardada correctamente')),
          );
        }
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la ruta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Center(
              child: Text(
                'Rutas del Servidor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView.builder(
                itemCount: _savedRoutes.length + 1, // +1 para el botón de añadir
                itemBuilder: (context, index) {
                  if (index == _savedRoutes.length) {
                    return ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Añadir nueva ruta'),
                      onTap: _showAddRouteDialog,
                    );
                  }
                  
                  final route = _savedRoutes[index];
                  return ListTile(
                    leading: widget.currentRoute == route
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.lan),
                    title: Text(route),
                    onTap: () {
                      widget.onRouteSelected(route);
                      Navigator.of(context).pop(); // Cerrar el drawer
                    },
                    trailing: !_commonRoutes.contains(route)
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              final savedRoutes = prefs.getStringList('saved_routes') ?? [];
                              savedRoutes.remove(route);
                              await prefs.setStringList('saved_routes', savedRoutes);
                              await _loadSavedRoutes();
                            },
                          )
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
