import 'package:flutter/material.dart';
import 'dashboard_screen_web.dart';
import 'condominios_screen_web.dart'; // Ajustado para seu arquivo real
import 'usuarios_screen_web.dart';
import 'leituras_screen_web.dart'; 
import '../main.dart'; // Para acessar o usuarioLogado

class MainWebScreen extends StatefulWidget {
  const MainWebScreen({super.key});

  @override
  State<MainWebScreen> createState() => _MainWebScreenState();
}

class _MainWebScreenState extends State<MainWebScreen> {
  int _indiceSelecionado = 0;

  @override
  Widget build(BuildContext context) {
    // A LISTA NÃO PODE SER CONST pois LeiturasScreenWeb recebe parâmetro
    final List<Widget> _telas = [
      const DashboardScreenWeb(),
      const CondominiosScreenWeb(),
      const UsuariosScreenWeb(),
      // Aqui passamos o ID do condomínio logado
      LeiturasScreenWeb(tenantId: usuarioLogado?.tenantId ?? 1),
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
            backgroundColor: Colors.blueGrey[900],
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.apartment), label: Text('Condomínios')),
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