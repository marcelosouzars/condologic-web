// ==========================================>>> main_web_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'condominios_screen_web.dart';
import 'usuarios_screen_web.dart';
import 'leituras_screen_web.dart';
import 'relatorios_screen_web.dart';
import 'exportacao_screen_web.dart';
import 'login_screen_web.dart';
import '../services/api_service_web.dart';

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

  // =========================================================================
  // NOVA FUNÇÃO: MODAL PARA O PRÓPRIO USUÁRIO ALTERAR SUA SENHA
  // =========================================================================
  void _abrirModalAlterarSenha() {
    final senhaAtualCtrl = TextEditingController();
    final novaSenhaCtrl = TextEditingController();
    final confirmaSenhaCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset, color: Colors.blue),
                SizedBox(width: 10),
                Text("Alterar Minha Senha"),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Sua nova senha deve ser mantida em segurança.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: senhaAtualCtrl, 
                    obscureText: true, 
                    decoration: const InputDecoration(labelText: "Senha Atual (Ex: 123456)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline))
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: novaSenhaCtrl, 
                    obscureText: true, 
                    decoration: const InputDecoration(labelText: "Nova Senha", border: OutlineInputBorder(), prefixIcon: Icon(Icons.key))
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: confirmaSenhaCtrl, 
                    obscureText: true, 
                    decoration: const InputDecoration(labelText: "Confirmar Nova Senha", border: OutlineInputBorder(), prefixIcon: Icon(Icons.key_off))
                  ),
                ]
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                onPressed: isSaving ? null : () async {
                  // VALIDAÇÕES
                  if (senhaAtualCtrl.text.isEmpty || novaSenhaCtrl.text.isEmpty || confirmaSenhaCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos!"), backgroundColor: Colors.red));
                    return;
                  }
                  if (novaSenhaCtrl.text != confirmaSenhaCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A confirmação não bate com a nova senha!"), backgroundColor: Colors.red));
                    return;
                  }

                  setStateModal(() => isSaving = true);
                  
                  try {
                    // Chama a API para trocar a senha
                    await ApiServiceWeb().alterarSenha(_usuarioLogado!['id'], senhaAtualCtrl.text, novaSenhaCtrl.text);
                    
                    if (mounted) {
                      Navigator.pop(context); // Fecha o modal
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sua senha foi atualizada com sucesso!"), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    setStateModal(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
                  }
                },
                icon: isSaving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, color: Colors.white),
                label: Text(isSaving ? "SALVANDO..." : "ATUALIZAR SENHA", style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
              )
            ]
          );
        }
      )
    );
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
      const ExportacaoScreenWeb(), 
    ];

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text('CondoLogic', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: false,
        backgroundColor: Colors.blue[900], 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), 
        actions: [
          // AQUI O BALÃO DO USUÁRIO VIROU UM BOTÃO CLICÁVEL (ActionChip)
          Center(
            child: Tooltip(
              message: "Clique para alterar sua senha",
              child: ActionChip(
                avatar: Icon(Icons.person, color: Colors.blue[900], size: 18),
                label: Text(
                  "${_usuarioLogado?['nome'] ?? 'Usuário'} (${_usuarioLogado?['tipo'] ?? ''})", 
                  style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)
                ),
                backgroundColor: Colors.white,
                onPressed: _abrirModalAlterarSenha,
              ),
            ),
          ),
          const SizedBox(width: 15),
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