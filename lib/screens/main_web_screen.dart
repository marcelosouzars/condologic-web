// ==========================================>>> main_web_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'dashboard_screen_web.dart';
import 'detalhe_condominio_web.dart';
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
  
  // Variáveis Multitenant
  List<dynamic> _meusCondominios = [];
  Map<String, dynamic>? _condominioSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarUsuarioECondominios();
  }

  Future<void> _carregarUsuarioECondominios() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('usuario_dados');

    if (userString != null) {
      _usuarioLogado = jsonDecode(userString);
      
      // Busca os condomínios que este usuário tem acesso
      int? userId = _usuarioLogado?['id'];
      String? nivel = _usuarioLogado?['nivel_acesso'] ?? _usuarioLogado?['nivel'];
      
      try {
        final dados = await ApiServiceWeb().getCondominios(usuarioId: userId, nivel: nivel);
        if (mounted) {
          setState(() {
            _meusCondominios = dados;
            if (_meusCondominios.isNotEmpty) {
              _condominioSelecionado = _meusCondominios[0];
              _usuarioLogado!['tenant_id'] = _condominioSelecionado!['id'];
            }
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _loading = false);
      }
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
                    await ApiServiceWeb().alterarSenha(_usuarioLogado!['id'], senhaAtualCtrl.text, novaSenhaCtrl.text);
                    if (mounted) {
                      Navigator.pop(context);
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

  void _abrirSeletorCondominio() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.blue[900]),
            const SizedBox(width: 10),
            Text("Trocar Condomínio", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _meusCondominios.length,
            itemBuilder: (c, i) {
              final cond = _meusCondominios[i];
              bool isAtivo = _condominioSelecionado?['id'] == cond['id'];
              
              return ListTile(
                leading: Icon(Icons.apartment, color: isAtivo ? Colors.blue[900] : Colors.grey),
                title: Text(cond['nome'], style: TextStyle(fontWeight: FontWeight.bold, color: isAtivo ? Colors.blue[900] : Colors.black)),
                subtitle: Text("CNPJ: ${cond['cnpj'] ?? 'N/A'}"),
                trailing: isAtivo ? const Icon(Icons.check_circle, color: Colors.green) : null,
                tileColor: isAtivo ? Colors.blue[50] : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () {
                  setState(() {
                    _condominioSelecionado = cond;
                    _usuarioLogado!['tenant_id'] = cond['id'];
                    _selectedIndex = 0; 
                  });
                  Navigator.pop(ctx);
                },
              );
            }
          )
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FECHAR", style: TextStyle(color: Colors.grey)))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    bool isMaster = _usuarioLogado?['nivel_acesso']?.toString().toLowerCase() == 'master' || 
                    _usuarioLogado?['nivel']?.toString().toLowerCase() == 'master';

    // MENU RESTAURADO COM A OPÇÃO "LEITURAS"
    List<NavigationRailDestination> menuItens = [
      const NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
      const NavigationRailDestination(icon: Icon(Icons.edit_document), selectedIcon: Icon(Icons.edit_document), label: Text('Cadastro')),
      const NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Usuários / Equipe')),
      const NavigationRailDestination(icon: Icon(Icons.water_drop_outlined), selectedIcon: Icon(Icons.water_drop), label: Text('Leituras')), // <- VOLTOU AQUI
      const NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('Relatórios')),
      const NavigationRailDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: Text('Exportar Dados')),
    ];

    if (isMaster) {
      menuItens.add(
        const NavigationRailDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: Text('Gerenciar Condomínios'))
      );
    }

    // TELAS SINCRONIZADAS COM O MENU
    List<Widget> telas = [
      DashboardScreenWeb(usuarioLogado: _usuarioLogado), // 0: Dashboard
      _condominioSelecionado != null // 1: Cadastro
          ? DetalheCondominioWeb(condominio: _condominioSelecionado!)
          : const Center(child: Text("Nenhum condomínio selecionado.")),
      const UsuariosScreenWeb(), // 2: Usuários
      LeiturasScreenWeb(tenantId: _usuarioLogado?['tenant_id'] ?? 1), // 3: Leituras <- VOLTOU AQUI
      const RelatoriosScreenWeb(), // 4: Relatórios
      const ExportacaoScreenWeb(), // 5: Exportação
    ];

    if (isMaster) {
      telas.add(CondominiosScreenWeb(usuarioLogado: _usuarioLogado)); // 6: Tela Geral do Master
    }

    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Column(
        children: [
          // ==========================================
          // CABEÇALHO SUPERIOR (TOP BAR MULTITENANT)
          // ==========================================
          Container(
            height: 75,
            padding: const EdgeInsets.symmetric(horizontal: 25),
            decoration: BoxDecoration(
              color: Colors.white, 
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]
            ),
            child: Row(
              children: [
                Icon(Icons.business, color: Colors.blue[900], size: 32),
                const SizedBox(width: 15),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_condominioSelecionado?['nome'] ?? 'Carregando...', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                    const Text("Condomínio Ativo", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(width: 25),
                ElevatedButton.icon(
                  onPressed: _abrirSeletorCondominio,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text("TROCAR CONDOMÍNIO", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50], 
                    foregroundColor: Colors.blue[900], 
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                ),
                const Spacer(),
                // PERFIL DO USUÁRIO LOGADO
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
                      side: BorderSide(color: Colors.blue[100]!),
                      onPressed: _abrirModalAlterarSenha,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                TextButton.icon(
                  onPressed: _logout, 
                  icon: Icon(Icons.exit_to_app, color: Colors.red[700]), 
                  label: Text('SAIR', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // ==========================================
          // ÁREA PRINCIPAL (MENU LATERAL + CONTEÚDO)
          // ==========================================
          Expanded(
            child: Row(
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
          ),
        ],
      ),
    );
  }
}
