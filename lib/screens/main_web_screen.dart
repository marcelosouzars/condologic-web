// ==========================================>>> main_web_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'condominios_screen_web.dart';
import 'usuarios_screen_web.dart';
import 'leituras_screen_web.dart';   
import 'relatorios_screen_web.dart';
import 'login_screen_web.dart';

class MainWebScreen extends StatefulWidget {
  const MainWebScreen({super.key});
  @override
  State<MainWebScreen> createState() => _MainWebScreenState();
}

class _MainWebScreenState extends State<MainWebScreen> {
  int _selectedIndex = 0; 
  Map<String, dynamic>? _usuarioLogado;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  Future<void> _carregarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('usuario_dados');
    
    if (userString != null) {
      setState(() {
        _usuarioLogado = jsonDecode(userString);
        _loading = false;
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreenWeb()));
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreenWeb()));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    int tenantIdAtual = _usuarioLogado?['tenant_id'] ?? 1;
    
    List<NavigationRailDestination> menuItens = [
      const NavigationRailDestination(
        icon: Icon(Icons.apartment_outlined),
        selectedIcon: Icon(Icons.apartment),
        label: Text('Condomínios'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: Text('Usuários / Equipe'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.water_drop_outlined),
        selectedIcon: Icon(Icons.water_drop),
        label: Text('Leituras'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: Text('Relatórios'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.download_outlined),
        selectedIcon: Icon(Icons.download),
        label: Text('Exportar Dados'),
      ),
    ];
    
    List<Widget> telas = [
      CondominiosScreenWeb(usuarioLogado: _usuarioLogado),
      const UsuariosScreenWeb(), 
      LeiturasScreenWeb(tenantId: tenantIdAtual),
      const RelatoriosScreenWeb(),
      const RelatoriosScreenWeb(), // Provisório até recriarmos a tela de exportação
    ];

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        // TEXTO EM BRANCO NO FUNDO AZUL
        title: Text('CondoLogic', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: false,
        backgroundColor: Colors.blue[900], 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), 
        actions: [
          Center(
            child: Chip(
              avatar: Icon(Icons.person, color: Colors.blue[900], size: 18),
              label: Text(
                "${_usuarioLogado?['nome'] ?? 'Usuário'} (${_usuarioLogado?['tipo'] ?? ''})", 
                style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)
              ),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 15),
          // BOTÃO SAIR EM BRANCO E BEM CLARO
          TextButton.icon(
            onPressed: _logout, 
            icon: const Icon(Icons.exit_to_app, color: Colors.white), 
            label: const Text('SAIR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraint) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraint.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      extended: true,
                      backgroundColor: Colors.white,
                      elevation: 5,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
                      selectedIconTheme: IconThemeData(color: Colors.blue[900], size: 30),
                      unselectedIconTheme: const IconThemeData(color: Colors.grey, size: 24),
                      selectedLabelTextStyle: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
                      unselectedLabelTextStyle: const TextStyle(color: Colors.grey),
                      destinations: menuItens,
                    ),
                  ),
                ),
              );
            }
          ),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
              ),
              child: _selectedIndex < telas.length 
                ? telas[_selectedIndex] 
                : const Center(child: Text("Tela em construção...")),
            ),
          ),
        ],
      ),
    );
  }
}