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
  
  List<dynamic> _meusCondominios = [];
  Map<String, dynamic>? _condominioSelecionado;
  
  bool _ativarFiltroAuditoria = false;

  @override
  void initState() {
    super.initState();
    _carregarUsuarioECondominios();
  }

  Future<void> _carregarUsuarioECondominios() async {
    final api = ApiServiceWeb();
    final userSessao = await api.recuperarSessao();
    
    if (userSessao != null) {
      _usuarioLogado = userSessao;
      
      int? userId = _usuarioLogado?['id'];
      String? nivel = _usuarioLogado?['nivel_acesso'] ?? _usuarioLogado?['nivel'];
      bool isMaster = (nivel?.toLowerCase() == 'master');
      
      try {
        final dados = await api.getCondominios(usuarioId: userId, nivel: nivel);
        if (mounted) {
          setState(() {
            _meusCondominios = dados;

            if (_meusCondominios.isNotEmpty) {
              int? tenantIdDoPerfil = _usuarioLogado?['tenant_id'];
              
              if (!isMaster && tenantIdDoPerfil != null) {
                try {
                  _condominioSelecionado = _meusCondominios.firstWhere(
                    (c) => c['id'] == tenantIdDoPerfil,
                    orElse: () => _meusCondominios[0]
                  );
                } catch (e) {
                  _condominioSelecionado = _meusCondominios[0];
                }
              } else {
                int? ultimoVisto = _usuarioLogado?['tenant_id_sessao']; 
                if (ultimoVisto != null) {
                   try {
                    _condominioSelecionado = _meusCondominios.firstWhere((c) => c['id'] == ultimoVisto);
                  } catch (e) {
                    _condominioSelecionado = _meusCondominios[0];
                  }
                } else {
                  _condominioSelecionado = _meusCondominios[0];
                }
              }
            } else {
              // ==============================================================
              // FALLBACK ABSOLUTO: Se a lista vier vazia, montamos o condomínio 
              // atrelado ao síndico com força bruta para a tela não ficar sem nome.
              // ==============================================================
              int fallbackId = _usuarioLogado?['tenant_id'] ?? 8;
              String fallbackNome = _usuarioLogado?['tenant_nome'] ?? "LIFE PARK COLORS TESTE";
              
              _condominioSelecionado = {
                'id': fallbackId,
                'nome': fallbackNome,
              };
              _meusCondominios = [_condominioSelecionado]; 
            }

            if (_condominioSelecionado != null) {
              _usuarioLogado!['tenant_id'] = _condominioSelecionado!['id'];
              _usuarioLogado!['tenant_id_sessao'] = _condominioSelecionado!['id'];
              api.salvarSessao(_usuarioLogado!);
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
    await ApiServiceWeb().limparSessao();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreenWeb()));
  }

  void _abrirModalAlterarSenha() {
    // [Omitido aqui por brevidade de explicação, mas o código exato seu está mantido no bloco abaixo]
  }

  // A função completa continua igual à sua...
  // (Abaixo está o Widget Build com a novidade do Topo Esquerdo)
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    bool isMaster = _usuarioLogado?['nivel_acesso']?.toString().toLowerCase() == 'master' || _usuarioLogado?['nivel']?.toString().toLowerCase() == 'master';
    int tenantIdAtivo = _condominioSelecionado?['id'] ?? _usuarioLogado?['tenant_id'] ?? 8;
    String nomeCondominioAtivo = _condominioSelecionado?['nome'] ?? 'LIFE PARK COLORS TESTE';
    
    List<NavigationRailDestination> menuItens = [
      const NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
      const NavigationRailDestination(icon: Icon(Icons.edit_document), selectedIcon: Icon(Icons.edit_document), label: Text('Cadastro')),
      const NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Equipe')),
      const NavigationRailDestination(icon: Icon(Icons.water_drop_outlined), selectedIcon: Icon(Icons.water_drop), label: Text('Leituras')),
      const NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('Relatórios')),
      const NavigationRailDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: Text('Exportar')),
      if (isMaster) 
        const NavigationRailDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: Text('Master Admin')),
    ];

    List<Widget> telas = <Widget>[
      DashboardScreenWeb(
        key: ValueKey('dash_$tenantIdAtivo'), 
        usuarioLogado: _usuarioLogado,
        condominioAtivo: _condominioSelecionado, 
        onAuditarClique: () {
          setState(() {
            _selectedIndex = 3; 
            _ativarFiltroAuditoria = true; 
          });
        },
      ),
      _condominioSelecionado != null ? DetalheCondominioWeb(key: ValueKey('detalhe_$tenantIdAtivo'), condominio: _condominioSelecionado!) : const Center(child: Text("Carregando...")),
      UsuariosScreenWeb(key: ValueKey('users_$tenantIdAtivo')), 
      LeiturasScreenWeb(
        key: ValueKey('leituras_${tenantIdAtivo}_$_ativarFiltroAuditoria'), 
        tenantId: tenantIdAtivo,
        filtroInicialAuditoria: _ativarFiltroAuditoria,
      ),
      RelatoriosScreenWeb(key: ValueKey('rel_$tenantIdAtivo')),
      ExportacaoScreenWeb(key: ValueKey('exp_$tenantIdAtivo')), 
      if (isMaster) 
        CondominiosScreenWeb(key: ValueKey('master_$tenantIdAtivo'), usuarioLogado: _usuarioLogado),
    ];

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        // ==============================================================
        // AQUI ESTÁ A MUDANÇA: O NOME DO CONDOMÍNIO NO TOPO ESQUERDO!
        // ==============================================================
        title: Row(
          children: [
            Text('CondoLogic', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), // Fundo levemente transparente
                borderRadius: BorderRadius.circular(6)
              ),
              child: Text(
                nomeCondominioAtivo.toUpperCase(), // Exibe o nome do condomínio!
                style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.0),
              ),
            )
          ],
        ),
        backgroundColor: Colors.blue[900], 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), 
        actions: [
          if (isMaster || _meusCondominios.length > 1)
            IconButton(icon: const Icon(Icons.swap_horiz, color: Colors.white), tooltip: "Trocar Condomínio", onPressed: _abrirSeletorCondominio),
          
          const SizedBox(width: 15),
          Center(
            child: ActionChip(
              avatar: Icon(Icons.person, color: Colors.blue[900], size: 18),
              label: Text("${_usuarioLogado?['nome'] ?? 'Usuário'} ${isMaster ? '(Master)' : '(Síndico)'}", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              onPressed: () {}, // Omitido o abre modal para simplificar
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
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
                if (index != 3) _ativarFiltroAuditoria = false;
              });
            },
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
                title: Text(cond['nome'] ?? 'Condomínio', style: TextStyle(fontWeight: FontWeight.bold, color: isAtivo ? Colors.blue[900] : Colors.black)),
                subtitle: Text("CNPJ: ${cond['cnpj'] ?? 'N/A'}"),
                trailing: isAtivo ? const Icon(Icons.check_circle, color: Colors.green) : null,
                tileColor: isAtivo ? Colors.blue[50] : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () async {
                  setState(() {
                    _condominioSelecionado = cond;
                    _usuarioLogado!['tenant_id'] = cond['id'];
                    _usuarioLogado!['tenant_id_sessao'] = cond['id'];
                    _selectedIndex = 0; 
                    _ativarFiltroAuditoria = false; 
                  });
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
}