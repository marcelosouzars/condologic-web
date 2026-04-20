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

  // =============================================================
  // MÁGICA DO F5: CARREGA E MANTÉM A SESSÃO ATIVA
  // =============================================================
  Future<void> _carregarUsuarioECondominios() async {
    final api = ApiServiceWeb();
    // Recupera do cofre o que estava salvo
    final userSessao = await api.recuperarSessao();
    
    if (userSessao != null) {
      _usuarioLogado = userSessao;
      
      int? userId = _usuarioLogado?['id'];
      String? nivel = _usuarioLogado?['nivel_acesso'] ?? _usuarioLogado?['nivel'];
      
      try {
        final dados = await api.getCondominios(usuarioId: userId, nivel: nivel);
        if (mounted) {
          setState(() {
            _meusCondominios = dados;
            if (_meusCondominios.isNotEmpty) {
              // Verifica se já tínhamos um condomínio selecionado antes do F5
              int? ultimoTenantId = _usuarioLogado?['tenant_id'];
              
              if (ultimoTenantId != null) {
                try {
                  _condominioSelecionado = _meusCondominios.firstWhere((c) => c['id'] == ultimoTenantId);
                } catch (e) {
                  _condominioSelecionado = _meusCondominios[0];
                }
              } else {
                _condominioSelecionado = _meusCondominios[0];
              }
              
              // Sincroniza o usuário logado com o condomínio ativo
              _usuarioLogado!['tenant_id'] = _condominioSelecionado!['id'];
              api.salvarSessao(_usuarioLogado!);
            }
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      // Se não tem nada no cofre, volta pro login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreenWeb()));
      });
    }
  }

  Future<void> _logout() async {
    await ApiServiceWeb().limparSessao();
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
                    decoration: const InputDecoration(labelText: "Senha Atual", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline))
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A confirmação não bate!"), backgroundColor: Colors.red));
                    return;
                  }
                  setStateModal(() => isSaving = true);
                  try {
                    await ApiServiceWeb().alterarSenha(_usuarioLogado!['id'], senhaAtualCtrl.text, novaSenhaCtrl.text);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Senha atualizada!"), backgroundColor: Colors.green));
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
                onTap: () async {
                  setState(() {
                    _condominioSelecionado = cond;
                    _usuarioLogado!['tenant_id'] = cond['id'];
                    _selectedIndex = 0; 
                  });
                  // Salva a nova escolha no cofre para o F5 não perder
                  await ApiServiceWeb().salvarSessao(_usuarioLogado!);
                  if (mounted) Navigator.pop(ctx);
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

    bool isMaster = _usuarioLogado?['nivel_acesso']?.toString().toLowerCase() == 'master' || _usuarioLogado?['nivel']?.toString().toLowerCase() == 'master';
    int tenantIdAtual = _usuarioLogado?['tenant_id'] ?? 1;
    
    List<NavigationRailDestination> menuItens = [
      const NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
      const NavigationRailDestination(icon: Icon(Icons.edit_document), selectedIcon: Icon(Icons.edit_document), label: Text('Cadastro')),
      const NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Equipe')),
      const NavigationRailDestination(icon: Icon(Icons.water_drop_outlined), selectedIcon: Icon(Icons.water_drop), label: Text('Leituras')),
      const NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('Relatórios')),
      const NavigationRailDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: Text('Exportar')),
    ];
    
    if (isMaster) {
      menuItens.add(const NavigationRailDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: Text('Master Admin')));
    }

    // ================================================================================
    // MÁGICA DO REFRESH IMEDIATO: O `ValueKey` força as telas a recarregarem do zero
    // sempre que o `tenantIdAtual` mudar no seletor de condomínios!
    // ================================================================================
    List<Widget> telas = [
      DashboardScreenWeb(key: ValueKey('dash_$tenantIdAtual'), usuarioLogado: _usuarioLogado),
      _condominioSelecionado != null ? DetalheCondominioWeb(key: ValueKey('detalhe_$tenantIdAtual'), condominio: _condominioSelecionado!) : const Center(child: Text("Selecione um condomínio.")),
      UsuariosScreenWeb(key: ValueKey('users_$tenantIdAtual')), 
      LeiturasScreenWeb(key: ValueKey('leituras_$tenantIdAtual'), tenantId: tenantIdAtual),
      RelatoriosScreenWeb(key: ValueKey('rel_$tenantIdAtual')),
      ExportacaoScreenWeb(key: ValueKey('exp_$tenantIdAtual')), 
    ];
    
    if (isMaster) {
      telas.add(CondominiosScreenWeb(key: ValueKey('master_$tenantIdAtual'), usuarioLogado: _usuarioLogado));
    }

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text('CondoLogic', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[900], 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), 
        actions: [
          IconButton(icon: const Icon(Icons.swap_horiz, color: Colors.white), tooltip: "Trocar Condomínio", onPressed: _abrirSeletorCondominio),
          Center(
            child: ActionChip(
              avatar: Icon(Icons.person, color: Colors.blue[900], size: 18),
              label: Text("${_usuarioLogado?['nome'] ?? 'Usuário'}", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              onPressed: _abrirModalAlterarSenha,
            ),
          ),
          const SizedBox(width: 15),
          TextButton.icon(
            onPressed: _logout, 
            icon: const Icon(Icons.exit_to_app, color: Colors.white), 
            label: const Text('SAIR', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            backgroundColor: Colors.white,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
            selectedIconTheme: IconThemeData(color: Colors.blue[900], size: 30),
            destinations: menuItens,
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
              child: _selectedIndex < telas.length ? telas[_selectedIndex] : const Center(child: Text("Em construção")),
            ),
          ),
        ],
      ),
    );
  }
}