import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'unidades_screen.dart';
import 'usuarios_screen.dart';
import 'leituras_screen.dart'; // Nome do arquivo que confirmamos na imagem
import '../main.dart';

class MainWebScreen extends StatefulWidget {
  const MainWebScreen({super.key});

  @override
  State<MainWebScreen> createState() => _MainWebScreenState();
}

class _MainWebScreenState extends State<MainWebScreen> {
  int _indiceSelecionado = 0;

  @override
  Widget build(BuildContext context) {
    // Lista de telas para o menu lateral
    // REMOVIDO O 'const' DA LISTA POIS AS TELAS AGORA SÃO DINÂMICAS
    final List<Widget> _telas = [
      const DashboardScreen(),
      const UnidadesScreen(),
      const UsuariosScreen(),
      // AQUI ESTÁ A MUDANÇA: Passamos o tenantId do usuário logado para a auditoria
      LeiturasScreenWeb(tenantId: usuarioLogado?.tenantId ?? 1), 
    ];

    return Scaffold(
      body: Row(
        children: [
          // --- MENU LATERAL (DRAWER FIXO) ---
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
                icon: Icon(Icons.fact_check), // Ícone de Auditoria
                label: Text('Auditoria IA'),
              ),
            ],
          ),
          
          const VerticalDivider(thickness: 1, width: 1),

          // --- CONTEÚDO PRINCIPAL ---
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