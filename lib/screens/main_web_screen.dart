import 'package:flutter/material.dart';
// Importações corrigidas usando o caminho completo do pacote
import 'package:web_admin/screens/dashboard_screen.dart';
import 'package:web_admin/screens/unidades_screen.dart';
import 'package:web_admin/screens/usuarios_screen.dart';
import 'package:web_admin/screens/leituras_screen.dart'; 
// Importando o main para pegar a variável global do usuário, se existir
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
    // Definimos a lista de telas sem 'const' para evitar o erro de compilação
    final List<Widget> _telas = [
      DashboardScreen(),
      UnidadesScreen(),
      UsuariosScreen(),
      // Chamando a tela de auditoria que criamos
      LeiturasScreenWeb(tenantId: 1), // Coloquei 1 fixo para teste, ou use sua variável global
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
            backgroundColor: const Color(0xFF263238), // blueGrey[900]
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.apartment),
                label: Text('Unidades'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Usuários'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fact_check),
                label: Text('Auditoria IA'),
              ),
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