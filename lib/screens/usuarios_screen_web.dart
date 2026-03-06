// ==========================================>>> usuarios_screen_web.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service_web.dart'; 

class UsuariosScreenWeb extends StatefulWidget {
  const UsuariosScreenWeb({super.key});

  @override
  State<UsuariosScreenWeb> createState() => _UsuariosScreenWebState();
}

class _UsuariosScreenWebState extends State<UsuariosScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  List<dynamic> _usuarios = [];
  List<dynamic> _condominios = [];
  bool _isLoading = true;
  Map<String, dynamic>? _usuarioLogado;
  
  final String baseUrl = "https://condologic-backend.onrender.com";

  // Controllers do Formulário
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  String _tipoSelecionado = 'Síndico';
  String _nivelSelecionado = 'usuario';
  int? _condominioSelecionado; 

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  // Função blindada para checar se é Master
  bool _verificarSeMaster() {
    if (_usuarioLogado == null) return false;
    String nivelAcesso = _usuarioLogado!['nivel_acesso']?.toString().toLowerCase() ?? 
                         _usuarioLogado!['nivel']?.toString().toLowerCase() ?? '';
    return nivelAcesso == 'master';
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('usuario_dados');
      if (userString != null) {
        _usuarioLogado = jsonDecode(userString);
      }

      bool isMaster = _verificarSeMaster();
      int tenantId = _usuarioLogado?['tenant_id'] ?? 1;

      // Busca a lista de Condomínios 
      int? userId = _usuarioLogado?['id'];
      String? nivel = _usuarioLogado?['nivel_acesso'] ?? _usuarioLogado?['nivel'];
      final dadosCondo = await _apiService.getCondominios(usuarioId: userId, nivel: nivel);

      // Buscar usuários usando a rota correta do adminController
      String rotaUsuarios = isMaster 
          ? '$baseUrl/api/admin/usuarios' 
          : '$baseUrl/api/admin/usuarios?tenant_id=$tenantId';

      final response = await http.get(Uri.parse(rotaUsuarios));

      setState(() {
        _condominios = dadosCondo;
        if (response.statusCode == 200) {
          _usuarios = json.decode(response.body);
        } else {
          print("Erro da API ao buscar usuários: ${response.statusCode} - ${response.body}");
        }
        _isLoading = false;
      });
    } catch (e) {
      print("Erro ao carregar usuários: $e");
      setState(() => _isLoading = false);
    }
  }

  String _getNomeCondominio(int? tenantId) {
    if (tenantId == null) return 'Acesso Global / Master';
    final condo = _condominios.firstWhere((c) => c['id'] == tenantId, orElse: () => null);
    return condo != null ? condo['nome'] : 'Condomínio Desconhecido';
  }

  // --- NOVA FUNÇÃO REAL DE SALVAR NO BANCO ---
  Future<void> _salvarUsuario() async {
    bool isMaster = _verificarSeMaster();
    int? tenantParaSalvar = isMaster ? _condominioSelecionado : _usuarioLogado?['tenant_id'];

    if (tenantParaSalvar == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione um Condomínio!'), backgroundColor: Colors.red));
      return;
    }

    if (_nomeController.text.isEmpty || _cpfController.text.isEmpty || _senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    Navigator.pop(context); // Fecha o modal

    try {
      final body = {
        'nome': _nomeController.text,
        'cpf': _cpfController.text.replaceAll(RegExp(r'[^0-9]'), ''), 
        'senha': _senhaController.text, 
        'tipo': _tipoSelecionado,
        'nivel_acesso': _nivelSelecionado,
        'tenant_id': tenantParaSalvar
      };

      // Rota correta apontando para api/admin/usuario
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/usuario'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário salvo com sucesso!'), backgroundColor: Colors.green));
        _carregarDados(); 
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: ${response.body}'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro de conexão: $e'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _excluirUsuario(Map<String, dynamic> usuario) async {
    String nivelAlvo = usuario['nivel_acesso']?.toString().toLowerCase() ?? usuario['nivel']?.toString().toLowerCase() ?? '';
    if (nivelAlvo == 'master') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ação Bloqueada: O usuário MASTER não pode ser excluído.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final response = await http.delete(Uri.parse('$baseUrl/api/admin/usuario/${usuario['id']}'));
      if (response.statusCode == 200 || response.statusCode == 204) {
        _carregarDados();
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário excluído.'), backgroundColor: Colors.green));
      } else {
        throw Exception("Erro no servidor ao excluir.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
    }
  }

  void _confirmarExclusao(Map<String, dynamic> u) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('Excluir Usuário'),
          ],
        ),
        content: Text('Deseja realmente remover o usuário:\n\n"${u['nome']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELA', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(ctx);
              _excluirUsuario(u); 
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('EXCLUIR', style: TextStyle(color: Colors.white))
          ),
        ],
      )
    );
  }

  void _abrirModal() {
    _nomeController.clear();
    _cpfController.clear();
    _senhaController.clear();
    _tipoSelecionado = 'Síndico';
    _nivelSelecionado = 'usuario';
    
    bool isMaster = _verificarSeMaster();
    _condominioSelecionado = isMaster ? null : _usuarioLogado?['tenant_id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text('INCLUIR USUÁRIO', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMaster) ...[
                        DropdownButtonFormField<int>(
                          value: _condominioSelecionado,
                          decoration: const InputDecoration(labelText: 'Vincular ao Condomínio', border: OutlineInputBorder()),
                          items: _condominios.map<DropdownMenuItem<int>>((c) {
                            return DropdownMenuItem<int>(
                              value: c['id'],
                              child: Text(c['nome']),
                            );
                          }).toList(),
                          onChanged: (novo) => setStateModal(() => _condominioSelecionado = novo),
                        ),
                        const SizedBox(height: 15),
                      ],

                      TextField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder())),
                      const SizedBox(height: 15),
                      TextField(controller: _cpfController, decoration: const InputDecoration(labelText: 'CPF (Apenas números)', border: OutlineInputBorder())),
                      const SizedBox(height: 15),
                      TextField(controller: _senhaController, obscureText: true, decoration: const InputDecoration(labelText: 'Senha de Acesso', border: OutlineInputBorder())),
                      const SizedBox(height: 15),
                      
                      DropdownButtonFormField<String>(
                        value: _tipoSelecionado,
                        decoration: const InputDecoration(labelText: 'Cargo / Função', border: OutlineInputBorder()),
                        items: ['Síndico', 'Zelador', 'Leiturista', 'Administrador'].map((String valor) {
                          return DropdownMenuItem<String>(value: valor, child: Text(valor));
                        }).toList(),
                        onChanged: (novo) => setStateModal(() => _tipoSelecionado = novo!),
                      ),
                      const SizedBox(height: 15),
                      
                      DropdownButtonFormField<String>(
                        value: _nivelSelecionado,
                        decoration: const InputDecoration(labelText: 'Nível no Sistema', border: OutlineInputBorder()),
                        items: ['usuario', 'admin'].map((String valor) {
                          return DropdownMenuItem<String>(value: valor, child: Text(valor.toUpperCase()));
                        }).toList(),
                        onChanged: (novo) => setStateModal(() => _nivelSelecionado = novo!),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.red))),
                ElevatedButton.icon(
                  onPressed: _salvarUsuario, 
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('SALVAR', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMaster = _verificarSeMaster();
    bool podeEditar = isMaster || (_usuarioLogado?['nivel_acesso']?.toString().toLowerCase() == 'admin');

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Text('USUÁRIOS / EQUIPE', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
            if (podeEditar)
              ElevatedButton.icon(
                onPressed: _abrirModal, 
                icon: const Icon(Icons.person_add, color: Colors.white), 
                label: const Text('INCLUIR USUÁRIO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
              ),
          ]
        ),
        const SizedBox(height: 20),
        
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : _usuarios.isEmpty
                ? const Center(child: Text('Nenhum usuário encontrado.', style: TextStyle(fontSize: 16, color: Colors.grey)))
                : ListView.builder(
                    itemCount: _usuarios.length, 
                    itemBuilder: (ctx, index) {
                      final u = _usuarios[index];
                      String nivelUser = u['nivel_acesso']?.toString().toLowerCase() ?? u['nivel']?.toString().toLowerCase() ?? '';
                      bool isEsteUsuarioMaster = nivelUser == 'master';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isEsteUsuarioMaster ? Colors.red[900] : Colors.blue[100],
                            child: Icon(isEsteUsuarioMaster ? Icons.admin_panel_settings : Icons.person, color: isEsteUsuarioMaster ? Colors.white : Colors.blue[900]),
                          ),
                          title: Text(u['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Condomínio: ${_getNomeCondominio(u['tenant_id'])}\nCargo: ${u['tipo'] ?? '-'} | Nível: ${nivelUser.toUpperCase()}'),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (podeEditar)
                                IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () {}),
                              if (podeEditar && !isEsteUsuarioMaster)
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmarExclusao(u)),
                              if (isEsteUsuarioMaster)
                                const Tooltip(message: "Usuário Protegido", child: Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.lock, color: Colors.grey))),
                            ],
                          ),
                        ),
                      );
                    }
                  )
        ),
      ]
    );
  }
}