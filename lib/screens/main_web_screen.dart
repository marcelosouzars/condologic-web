import 'package:flutter/material.dart';
// Importações ajustadas para os nomes REAIS dos seus arquivos (com _web.dart)
import 'package:web_admin/screens/dashboard_screen_web.dart';
import 'package:web_admin/screens/unidades_screen_web.dart';
import 'package:web_admin/screens/usuarios_screen_web.dart';
import 'package:web_admin/screens/leituras_screen_web.dart'; 
import 'package:web_admin/main.dart';

class MainWebScreen extends StatefulWidget {
  const MainWebScreen({super.key});

  @override
  State<MainWebScreen> createState() => _MainWebScreenState();
}

class _MainWebScreenState extends State<MainWebScreen> {
  int _indiceSelecionado = 0;

  @override
  Widget build(BuildContext context) {
    // Lista de telas corrigida com os nomes das classes que estão nos seus arquivos
    final List<Widget> _telas = [
      DashboardScreenWeb(),
      UnidadesScreenWeb(),
      UsuariosScreenWeb(),
      LeiturasScreenWeb(tenantId: 1), 
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _indiceSelecionado,
            onDestinationSelected: (int index) {
              setState(() {
                _indiceSelecionado = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: const Color(0xFF263238),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.apartment), label: Text('Unidades')),
              NavigationRailDestination(icon: Icon(Icons.people), label: Text('Usuários')),
              NavigationRailDestination(icon: Icon(Icons.fact_check), label: Text('Auditoria IA')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: _telas[_indiceSelecionado],
            ),
          ),
        ],
      ),
    );
  }
}