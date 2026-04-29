// ==========================================>>> condominios_screen_web.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service_web.dart';
import 'detalhe_condominio_web.dart';

class CondominiosScreenWeb extends StatefulWidget {
  final Map<String, dynamic>? usuarioLogado;
  const CondominiosScreenWeb({super.key, this.usuarioLogado});
  @override
  State<CondominiosScreenWeb> createState() => _CondominiosScreenWebState();
}

class _CondominiosScreenWebState extends State<CondominiosScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  List<dynamic> _condominios = [];
  List<dynamic> _sindicosCadastrados = []; 
  bool _isLoading = true;

  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _sindicoNomeController = TextEditingController(); 
  final _precoAguaController = TextEditingController(); 
  final _precoAguaQuenteController = TextEditingController(); 
  final _precoGasController = TextEditingController();
  final _diaCorteController = TextEditingController();
  final _enderecoController = TextEditingController(); 
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  final _cepController = TextEditingController();
  final _telefoneCondoController = TextEditingController();
  final _emailCondoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      int? userId;
      String? nivel;
      if (widget.usuarioLogado != null) {
        userId = widget.usuarioLogado!['id'];
        nivel = widget.usuarioLogado!['nivel_acesso'] ?? widget.usuarioLogado!['nivel'];
      }
      
      final dadosCondo = await _apiService.getCondominios(usuarioId: userId, nivel: nivel);
      
      List<dynamic> listaSindicos = [];
      if (nivel?.toLowerCase() == 'master') {
        try {
          final todosUsuarios = await _apiService.getUsuarios();
          listaSindicos = todosUsuarios.where((u) => 
            u['tipo'].toString().toLowerCase() == 'sindico' || 
            u['tipo'].toString().toLowerCase() == 'síndico'
          ).toList();
        } catch (e) {
          print("Erro ao carregar síndicos: $e"); 
        }
      }

      if (mounted) {
        setState(() {
          _condominios = dadosCondo;
          _sindicosCadastrados = listaSindicos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _excluir(int id) async {
    try {
      String nivelAcesso = widget.usuarioLogado?['nivel_acesso'] ?? widget.usuarioLogado?['nivel'] ?? '';
      await _apiService.excluirCondominio(id, nivelAcesso);
      _carregarDados();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Condomínio Excluído com sucesso.'), backgroundColor: Colors.green));
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _salvarCondominio({int? idEdicao}) async {
    try {
      String enderecoCompleto = "${_enderecoController.text}, ${_numeroController.text} - ${_bairroController.text}";
      
      double valAgua = double.tryParse(_precoAguaController.text.replaceAll(',', '.')) ?? 0.0;
      double valAguaQuente = double.tryParse(_precoAguaQuenteController.text.replaceAll(',', '.')) ?? 0.0;
      double valGas = double.tryParse(_precoGasController.text.replaceAll(',', '.')) ?? 0.0;

      final dados = {
        'nome': _nomeController.text, 
        'cnpj': _cnpjController.text, 
        'nome_sindico': _sindicoNomeController.text,
        'endereco_completo': enderecoCompleto,
        'endereco': _enderecoController.text,
        'endereco_numero': _numeroController.text,
        'endereco_complemento': _complementoController.text,
        'endereco_bairro': _bairroController.text,
        'cidade': _cidadeController.text, 
        'estado': _estadoController.text, 
        'cep': _cepController.text,
        'telefone_sindico': _telefoneCondoController.text,
        'email_sindico': _emailCondoController.text,
        'valor_m3_agua': valAgua,
        'valor_m3_agua_quente': valAguaQuente,
        'valor_m3_gas': valGas,
        'dia_corte': int.tryParse(_diaCorteController.text) ?? 1,
        'tipo_estrutura': 'vertical'
      };

      if (idEdicao != null) {
        await _apiService.editarCondominio(idEdicao, dados);
      } else {
        await _apiService.criarCondominio(
          dados,
          usuarioId: widget.usuarioLogado?['id'],
          nivel: widget.usuarioLogado?['nivel_acesso'] ?? widget.usuarioLogado?['nivel']
        );
      }
      
      if (mounted) {
        Navigator.pop(context); 
        _carregarDados();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados Salvos!'), backgroundColor: Colors.green));
      }
    } catch (e) { 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  void _abrirModal({Map<String, dynamic>? item}) {
    Map<String, dynamic>? sindicoSelecionado;

    if (item != null) {
      _nomeController.text = item['nome'] ?? '';
      _cnpjController.text = item['cnpj'] ?? '';
      _sindicoNomeController.text = item['nome_sindico'] ?? '';
      _enderecoController.text = item['endereco'] ?? ''; 
      _numeroController.text = item['endereco_numero'] ?? '';
      _complementoController.text = item['endereco_complemento'] ?? '';
      _bairroController.text = item['endereco_bairro'] ?? '';
      _cidadeController.text = item['cidade'] ?? '';
      _estadoController.text = item['estado'] ?? '';
      _cepController.text = item['cep'] ?? '';
      _precoAguaController.text = (item['valor_m3_agua'] ?? 0).toString();
      _precoAguaQuenteController.text = (item['valor_m3_agua_quente'] ?? 0).toString();
      _precoGasController.text = (item['valor_m3_gas'] ?? 0).toString();
      _diaCorteController.text = (item['dia_corte'] ?? 1).toString();
      _telefoneCondoController.text = item['telefone_sindico'] ?? item['telefone_condominio'] ?? '';
      _emailCondoController.text = item['email_sindico'] ?? item['email_condominio'] ?? '';

      try {
        if (_sindicoNomeController.text.isNotEmpty) {
          sindicoSelecionado = _sindicosCadastrados.firstWhere(
            (s) => s['nome'] == _sindicoNomeController.text,
            orElse: () => null,
          ) as Map<String, dynamic>?;
        }
      } catch (e) {
        sindicoSelecionado = null; 
      }
    } else {
      _nomeController.clear(); _cnpjController.clear(); _sindicoNomeController.clear(); _enderecoController.clear();
      _numeroController.clear(); _complementoController.clear(); _bairroController.clear();
      _cidadeController.clear(); _estadoController.clear(); _cepController.clear();
      _telefoneCondoController.clear(); _emailCondoController.clear();
      _precoAguaController.text = "0.00"; _precoAguaQuenteController.text = "0.00"; _precoGasController.text = "0.00"; _diaCorteController.text = "1";
    }

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
                title: Text(item == null ? 'INCLUIR CONDOMÍNIO' : 'EDITAR CONDOMÍNIO', style: const TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: 800, 
                  height: 600, 
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        const Text("1. Dados Principais e Contato", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 10),
                        Row(children: [
                            Expanded(flex: 2, child: _buildTextField('Nome do Condomínio', _nomeController)),
                            const SizedBox(width: 10),
                            Expanded(flex: 1, child: _buildTextField('CNPJ', _cnpjController)),
                        ]),
                        const SizedBox(height: 15),
                        
                        if (_sindicosCadastrados.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.5))
                            ),
                            child: DropdownButtonFormField<Map<String, dynamic>>(
                              value: sindicoSelecionado,
                              decoration: const InputDecoration(
                                labelText: 'Vincular Síndico Cadastrado (Opcional)', 
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.person_search, color: Colors.orange)
                              ),
                              items: [
                                const DropdownMenuItem<Map<String, dynamic>>(
                                  value: null, 
                                  child: Text("Digitar dados do Síndico manualmente", style: TextStyle(fontStyle: FontStyle.italic))
                                ),
                                ..._sindicosCadastrados.map((s) => DropdownMenuItem<Map<String, dynamic>>(
                                  value: s as Map<String, dynamic>, 
                                  child: Text(s['nome'])
                                )).toList(),
                              ],
                              onChanged: (val) {
                                setStateModal(() {
                                  sindicoSelecionado = val;
                                  if (val != null) {
                                    _sindicoNomeController.text = val['nome'] ?? '';
                                    _telefoneCondoController.text = val['telefone'] ?? '';
                                    _emailCondoController.text = val['email'] ?? '';
                                  } else {
                                    _sindicoNomeController.clear();
                                    _telefoneCondoController.clear();
                                    _emailCondoController.clear();
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 15),
                        ],

                        Row(children: [
                            Expanded(flex: 2, child: _buildTextField('Nome do Síndico / Gestor', _sindicoNomeController)),
                            const SizedBox(width: 10),
                            Expanded(flex: 1, child: _buildTextField('Telefone', _telefoneCondoController)),
                            const SizedBox(width: 10),
                            Expanded(flex: 1, child: _buildTextField('E-mail', _emailCondoController)),
                        ]),

                        const Divider(height: 30),

                        const Text("2. Endereço Completo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 10),
                        Row(children: [
                            Expanded(flex: 1, child: _buildTextField('CEP', _cepController)),
                            const SizedBox(width: 10),
                            Expanded(flex: 3, child: _buildTextField('Logradouro (Rua)', _enderecoController)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                            Expanded(child: _buildTextField('Número', _numeroController)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildTextField('Complemento', _complementoController)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildTextField('Bairro', _bairroController)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                            Expanded(flex: 3, child: _buildTextField('Cidade', _cidadeController)),
                            const SizedBox(width: 10),
                            Expanded(flex: 1, child: _buildTextField('UF', _estadoController)),
                        ]),

                        const Divider(height: 30),

                        const Text("3. Parâmetros do Condomínio", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _buildTextField('m³ Água Fria (R\$)', _precoAguaController)), 
                          const SizedBox(width: 10), 
                          Expanded(child: _buildTextField('m³ Água Quente (R\$)', _precoAguaQuenteController)), 
                          const SizedBox(width: 10), 
                          Expanded(child: _buildTextField('m³ Gás (R\$)', _precoGasController)), 
                          const SizedBox(width: 10), 
                          Expanded(child: _buildTextField('Dia de Corte', _diaCorteController))
                        ]),
                      ]
                    )
                  )
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.red))),
                  ElevatedButton.icon(
                    onPressed: () => _salvarCondominio(idEdicao: item?['id']), 
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('SALVAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
            );
          }
        );
      }
    );
  }

  void _confirmarExclusao(Map<String, dynamic> c) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('ATENÇÃO - Excluir Registro'),
          ],
        ),
        content: Text('Você tem certeza que deseja excluir o condomínio:\n\n"${c['nome']}"?\n\nEsta ação apagará todas as unidades, relógios e leituras associadas a ele. Não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELA', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(ctx);
              _excluir(c['id']); 
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('OK, EXCLUIR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );
  }

  Widget _buildTextField(String l, TextEditingController c) => TextField(controller: c, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), isDense: true));

  @override
  Widget build(BuildContext context) {
    String nivelUsuario = widget.usuarioLogado?['nivel_acesso']?.toString().toLowerCase() ?? widget.usuarioLogado?['nivel']?.toString().toLowerCase() ?? '';
    bool isMaster = (nivelUsuario == 'master');
    bool isAdmin = (nivelUsuario == 'admin');
    
    // Tanto Master quanto Admin(Síndico) podem criar e editar
    bool podeCriarEditar = isMaster || isAdmin || widget.usuarioLogado == null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Text(isMaster ? 'GESTÃO GLOBAL' : 'MEUS CONDOMÍNIOS', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
            if (podeCriarEditar) 
              ElevatedButton.icon(
                onPressed: () => _abrirModal(), 
                icon: const Icon(Icons.add, color: Colors.white), 
                label: const Text('INCLUIR CONDOMÍNIO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
              ),
          ]
        ),
        const SizedBox(height: 20),
        
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : ListView.builder(
                itemCount: _condominios.length, 
                itemBuilder: (ctx, index) {
                  final c = _condominios[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10), 
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)), 
                          child: Icon(Icons.apartment, size: 30, color: Colors.blue[900])
                        ),
                        title: Text(c['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CNPJ: ${c['cnpj'] ?? 'Não informado'} | Telefone: ${c['telefone_sindico'] ?? c['telefone_condominio'] ?? 'Não informado'}'),
                            const SizedBox(height: 5),
                            Text('Endereço: ${c['endereco_completo'] ?? c['endereco'] ?? 'Não informado'}', style: TextStyle(color: Colors.grey[700])),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('Água Fria: R\$ ${c['valor_m3_agua'] ?? '0.00'}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(width: 15),
                                Text('Água Quente: R\$ ${c['valor_m3_agua_quente'] ?? '0.00'}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(width: 15),
                                Text('Gás: R\$ ${c['valor_m3_gas'] ?? '0.00'}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            if (podeCriarEditar) 
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange), 
                                tooltip: "Editar Condomínio", 
                                onPressed: () => _abrirModal(item: c)
                              ),
                            if (isMaster) 
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red), 
                                tooltip: "Excluir Condomínio", 
                                onPressed: () => _confirmarExclusao(c)
                              ),
                            const SizedBox(width: 10),
                            const VerticalDivider(),
                            Tooltip(
                              message: "Abrir Blocos e Unidades",
                              child: IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue), 
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalheCondominioWeb(condominio: c)))
                              ),
                            ),
                          ]
                        ),
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