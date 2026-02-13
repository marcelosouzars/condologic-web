import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service_web.dart'; // Certifique-se que o caminho está certo

class UsuariosScreenWeb extends StatefulWidget {
  const UsuariosScreenWeb({super.key});

  @override
  State<UsuariosScreenWeb> createState() => _UsuariosScreenWebState();
}

class _UsuariosScreenWebState extends State<UsuariosScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  List<dynamic> _usuarios = [];
  List<dynamic> _condominios = []; // Lista para o Dropdown
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final usuarios = await _apiService.getUsuarios();
      final condominios = await _apiService.getCondominios(); // Precisamos buscar os condominios
      setState(() {
        _usuarios = usuarios;
        _condominios = condominios;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Ignora erro se não conseguir carregar, mas idealmente exibiria alerta
    }
  }

  Future<void> _excluirUsuario(int id) async {
    if (!await _confirmarExclusao()) return;
    try {
      await _apiService.excluirUsuario(id);
      _carregarDados();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<bool> _confirmarExclusao() async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('Tem certeza que deseja excluir este usuário?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  void _abrirModalUsuario({Map<String, dynamic>? usuario}) {
    final nomeController = TextEditingController(text: usuario?['nome'] ?? '');
    final cpfController = TextEditingController(text: usuario?['cpf'] ?? '');
    final senhaController = TextEditingController();
    
    // Valores iniciais do Dropdown
    String tipoSelecionado = usuario?['tipo'] ?? 'leiturista';
    int? tenantIdSelecionado = usuario?['tenant_id'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: Text(usuario == null ? 'Novo Usuário' : 'Editar Usuário'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nomeController,
                        decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: cpfController,
                        decoration: const InputDecoration(labelText: 'CPF (apenas números ou formatado)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      if (usuario == null) // Só mostra senha se for novo
                        TextField(
                          controller: senhaController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                        ),
                      const SizedBox(height: 10),
                      
                      // --- DROPDOWN TIPO ---
                      DropdownButtonFormField<String>(
                        value: tipoSelecionado,
                        decoration: const InputDecoration(labelText: 'Função', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'leiturista', child: Text('Leiturista / Zelador')),
                          DropdownMenuItem(value: 'admin', child: Text('Administrador / Síndico')),
                          DropdownMenuItem(value: 'master', child: Text('Master (Suporte)')),
                        ],
                        onChanged: (v) => setStateModal(() => tipoSelecionado = v!),
                      ),
                      
                      const SizedBox(height: 15),
                      const Text("Vincular a qual Condomínio?", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),

                      // --- DROPDOWN CONDOMINIO (AQUI ESTÁ A MÁGICA) ---
                      DropdownButtonFormField<int>(
                        value: tenantIdSelecionado,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Selecione o Condomínio', 
                          border: OutlineInputBorder(),
                          helperText: 'O usuário só verá dados deste condomínio.'
                        ),
                        items: _condominios.map<DropdownMenuItem<int>>((condo) {
                          return DropdownMenuItem<int>(
                            value: condo['id'],
                            child: Text(condo['nome'], overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) => setStateModal(() => tenantIdSelecionado = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (tenantIdSelecionado == null && tipoSelecionado != 'master') {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um condomínio!')));
                       return;
                    }

                    final dados = {
                      'nome': nomeController.text,
                      'cpf': cpfController.text,
                      'tipo': tipoSelecionado,
                      'tenant_id': tenantIdSelecionado, // Enviando o ID do condomínio
                    };

                    try {
                      if (usuario == null) {
                        dados['senha'] = senhaController.text;
                        await _apiService.criarUsuario(dados);
                      } else {
                        await _apiService.editarUsuario(usuario['id'], dados);
                      }
                      if (mounted) {
                        Navigator.pop(ctx);
                        _carregarDados();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text('SALVAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestão de Equipe', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _abrirModalUsuario(),
                        icon: const Icon(Icons.person_add),
                        label: const Text("NOVO USUÁRIO"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _usuarios.length,
                      itemBuilder: (context, index) {
                        final u = _usuarios[index];
                        // Descobrir nome do condomínio baseado no ID
                        final condo = _condominios.firstWhere(
                          (c) => c['id'] == u['tenant_id'], 
                          orElse: () => {'nome': 'Não vinculado'}
                        );

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: Text(u['nome'].substring(0, 1).toUpperCase()),
                            ),
                            title: Text(u['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${u['tipo'].toString().toUpperCase()} - CPF: ${u['cpf']}'),
                                Text('Condomínio: ${condo['nome']}', style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _abrirModalUsuario(usuario: u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _excluirUsuario(u['id']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}