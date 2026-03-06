// ==========================================>>> usuarios_screen_web.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class UsuariosScreenWeb extends StatefulWidget {
  const UsuariosScreenWeb({super.key});

  @override
  State<UsuariosScreenWeb> createState() => _UsuariosScreenWebState();
}

class _UsuariosScreenWebState extends State<UsuariosScreenWeb> {
  List<dynamic> _usuarios = [];
  bool _isLoading = true;
  Map<String, dynamic>? _usuarioLogado;
  
  final String baseUrl = "https://condologic-backend.onrender.com";

  // Controllers do Formulário
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  String _tipoSelecionado = 'Zelador';
  String _nivelSelecionado = 'usuario';

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      // 1. Descobrir quem está logado
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('usuario_dados');
      if (userString != null) {
        _usuarioLogado = jsonDecode(userString);
      }

      // 2. Buscar usuários no backend
      // Se for Síndico, busca só do tenant dele. Se for Master, busca todos.
      int tenantId = _usuarioLogado?['tenant_id'] ?? 1;
      String rota = _usuarioLogado?['nivel_acesso'] == 'master' 
          ? '$baseUrl/api/usuarios' // Rota genérica para o master (ajuste conforme seu backend)
          : '$baseUrl/api/usuarios?tenant_id=$tenantId';

      final response = await http.get(Uri.parse(rota));

      if (response.statusCode == 200) {
        setState(() {
          _usuarios = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Erro ao carregar usuários: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _excluirUsuario(Map<String, dynamic> usuario) async {
    // TRAVA DE SEGURANÇA: NUNCA EXCLUIR O MASTER
    if (usuario['nivel_acesso']?.toString().toLowerCase() == 'master') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ação Bloqueada: O usuário MASTER não pode ser excluído pelo sistema.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final response = await http.delete(Uri.parse('$baseUrl/api/usuarios/${usuario['id']}'));
      if (response.statusCode == 200 || response.statusCode == 204) {
        _carregarDados();
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário excluído.'), backgroundColor: Colors.green));
      } else {
        throw Exception("Erro no servidor");
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
    _tipoSelecionado = 'Zelador';
    _nivelSelecionado = 'usuario';

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
                        decoration: const InputDecoration(labelText: 'Nível de Acesso', border: OutlineInputBorder()),
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
                  onPressed: () {
                    Navigator.pop(context);
                    // Aqui entra a lógica de salvar na API (Post)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Função de salvar em construção na API.'), backgroundColor: Colors.orange));
                  },
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
    bool podeEditar = (_usuarioLogado?['nivel_acesso'] == 'master' || _usuarioLogado?['nivel_acesso'] == 'admin');

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
            : ListView.builder(
                itemCount: _usuarios.length, 
                itemBuilder: (ctx, index) {
                  final u = _usuarios[index];
                  bool isMaster = (u['nivel_acesso']?.toString().toLowerCase() == 'master');
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isMaster ? Colors.red[900] : Colors.blue[100],
                        child: Icon(isMaster ? Icons.admin_panel_settings : Icons.person, color: isMaster ? Colors.white : Colors.blue[900]),
                      ),
                      title: Text(u['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Cargo: ${u['tipo'] ?? '-'} | Nível: ${u['nivel_acesso']?.toString().toUpperCase() ?? '-'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (podeEditar)
                            IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () {}),
                          // SÓ MOSTRA A LIXEIRA SE NÃO FOR MASTER
                          if (podeEditar && !isMaster)
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmarExclusao(u)),
                          // SE FOR MASTER, MOSTRA UM CADEADO
                          if (isMaster)
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