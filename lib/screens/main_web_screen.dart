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
      // Se não tiver ninguém logado na memória, chuta pra tela de login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreenWeb()));
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Limpa a memória
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreenWeb()));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    // Captura o ID do Condomínio logado (se for Master, pode vir nulo, então usamos 1 provisoriamente para não quebrar a tela de leituras)
    int tenantIdAtual = _usuarioLogado?['tenant_id'] ?? 1;
    
    // --- CONSTRUÇÃO DO MENU ---
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
    
    // --- CONSTRUÇÃO DAS TELAS (Na mesma ordem do menu) ---
    List<Widget> telas = [
      // A) CONDOMÍNIOS
      CondominiosScreenWeb(usuarioLogado: _usuarioLogado),
      
      // B) USUÁRIOS / EQUIPE
      const UsuariosScreenWeb(), // Em breve vamos passar o usuarioLogado pra cá também para travar o Síndico
      
      // C) LEITURAS
      LeiturasScreenWeb(tenantId: tenantIdAtual),
      
      // D) RELATÓRIOS
      const RelatoriosScreenWeb(),
      
      // E) EXPORTAR DADOS (Provisoriamente apontando para a tela de relatórios que já tem os botões de CSV/PDF)
      const RelatoriosScreenWeb(),
    ];

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text('CondoLogic', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: false,
        backgroundColor: Colors.blue[900], 
        elevation: 0,
        actions: [
          Center(
            child: Chip(
              avatar: const Icon(Icons.person, color: Colors.white, size: 18),
              label: Text(
                "${_usuarioLogado?['nome'] ?? 'Usuário'} (${_usuarioLogado?['tipo'] ?? ''})", 
                style: const TextStyle(color: Colors.white)
              ),
              backgroundColor: Colors.blue[800],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(icon: const Icon(Icons.exit_to_app), onPressed: _logout, tooltip: 'Sair'),
          const SizedBox(width: 20),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MENU LATERAL 
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
          
          // CONTEÚDO DINÂMICO DA TELA SELECIONADA
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