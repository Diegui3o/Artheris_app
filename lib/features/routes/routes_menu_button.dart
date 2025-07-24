import 'package:flutter/material.dart';
import 'routes_menu.dart';

class RoutesMenuButton extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onRouteSelected;

  const RoutesMenuButton({
    super.key,
    required this.currentRoute,
    required this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.route),
      tooltip: 'Cambiar ruta del servidor',
      onPressed: () {
        Scaffold.of(context).openEndDrawer();
      },
    );
  }
}

class RoutesMenuScaffold extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  final ValueChanged<String> onRouteSelected;

  const RoutesMenuScaffold({
    super.key,
    required this.child,
    required this.currentRoute,
    required this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: Drawer(
        child: RoutesMenu(
          currentRoute: currentRoute,
          onRouteSelected: onRouteSelected,
        ),
      ),
      body: child,
    );
  }
}
