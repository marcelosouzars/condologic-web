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
  bool _isLoading = true;

  // Controllers Condomínio (Dados Básicos)
  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _precoAguaController = TextEditingController(); 
  final _precoGasController = TextEditingController();
  final _diaCorteController = TextEditingController(); 
  
  // Controllers Endereço e Contato (NOVOS)
  final _enderecoController = TextEditingController(); // Rua
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  final _cepController = TextEditingController();
  final _telefoneCondoController = TextEditingController();
  final _emailCondoController = TextEditingController();

  // --- CONTROLE DE VÍNCULO SÍNDICO ---
  final _buscaUserController = TextEditingController();
  List<dynamic> _resultadosBusca = [];
  bool _buscandoUser = false;
  String? _nomeSindicoVinculado; 

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
        nivel = widget.usuarioLogado!['nivel'];
      }
      final dadosCondo = await _apiService.getCondominios(usuarioId: userId, nivel: nivel);
      setState(() {
        _condominios = dadosCondo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Busca APENAS SÍNDICOS
  Future<void> _buscarSindicoNoBanco(String termo) async {
    if (termo.length < 3) return;
    setState(() => _buscandoUser = true);
    try {
      final res = await _apiService.buscarUsuarios(termo);
      // FILTRO: Só deixa passar quem é 'sindico'
      final sindicos = res.where((u) => u['tipo'] == 'sindico').toList();
      setState(() {
        _resultadosBusca = sindicos;
        _buscandoUser = false;
      });
    } catch (e) { setState(() => _buscandoUser = false); }
  }

  Future<void> _vincularNaHora(Map<String, dynamic> usuario, int tenantId) async {
    try {
      await _apiService.vincularUsuario(usuario['id'], tenantId);
      setState(() {
        _nomeSindicoVinculado = usuario['nome'];
        _buscaUserController.clear();
        _resultadosBusca = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Síndico Vinculado!'), backgroundColor: Colors.green));
    } catch (e) { 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'))); 
    }
  }

  Future<void> _excluir(int id) async {
    try {
      await _apiService.excluirCondominio(id);
      _carregarDados();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Condomínio Excluído.')));
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _salvarCondominio({int? idEdicao}) async {
    try {
      String enderecoCompleto = "${_enderecoController.text}, ${_numeroController.text} - ${_bairroController.text}";
      
      final dados = {
        'nome': _nomeController.text, 
        'cnpj': _cnpjController.text, 
        'endereco': enderecoCompleto,
        'endereco_numero': _numeroController.text,
        'endereco_complemento': _complementoController.text,
        'endereco_bairro': _bairroController.text,
        'cidade': _cidadeController.text, 
        'estado': _estadoController.text, 
        'cep': _cepController.text,
        'telefone_condominio': _telefoneCondoController.text,
        'email_condominio': _emailCondoController.text,
        'valor_m3_agua': double.tryParse(_precoAguaController.text.replaceAll(',', '.')) ?? 0.0,
        'valor_m3_gas': double.tryParse(_precoGasController.text.replaceAll(',', '.')) ?? 0.0,
        'dia_corte': int.tryParse(_diaCorteController.text) ?? 1,
        'tipo_estrutura': 'vertical'
      };
      
      if (idEdicao != null) await _apiService.editarCondominio(idEdicao, dados);
      else await _apiService.criarCondominio(dados);
      
      if (mounted) {
        Navigator.pop(context);
        _carregarDados();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados Salvos!'), backgroundColor: Colors.green));
      }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'))); }
  }

  void _abrirModal({Map<String, dynamic>? item}) {
    _resultadosBusca = [];
    _buscaUserController.clear();
    _nomeSindicoVinculado = null;
    
    if (item != null) {
      _nomeController.text = item['nome'];
      _cnpjController.text = item['cnpj'];
      _enderecoController.text = item['endereco'] ?? ''; 
      _cidadeController.text = item['cidade'] ?? '';
      _estadoController.text = item['estado'] ?? '';
      _precoAguaController.text = (item['valor_m3_agua'] ?? 0).toString();
      _precoGasController.text = (item['valor_m3_gas'] ?? 0).toString();
      _diaCorteController.text = (item['dia_corte'] ?? 1).toString();
      if (item['nome_sindico'] != null) {
        _nomeSindicoVinculado = item['nome_sindico'];
      }
    } else {
      _nomeController.clear(); _cnpjController.clear(); _enderecoController.clear();
      _numeroController.clear(); _complementoController.clear(); _bairroController.clear();
      _cidadeController.clear(); _estadoController.clear(); _cepController.clear();
      _telefoneCondoController.clear(); _emailCondoController.clear();
      _precoAguaController.text = "0.00"; _precoGasController.text = "0.00"; _diaCorteController.text = "1";
    }

    showDialog(context: context, builder: (context) {
        return StatefulBuilder(builder: (context, setStateModal) {
            return AlertDialog(
                title: Text(item == null ? 'Novo Condomínio' : 'Editar Condomínio'),
                content: SizedBox(width: 800, height: 600, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        
                        const Text("1. Identificação", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 10),
                        Row(children: [
                           Expanded(flex: 2, child: _buildTextField('Nome do Condomínio', _nomeController)),
                           const SizedBox(width: 10),
                           Expanded(flex: 1, child: _buildTextField('CNPJ', _cnpjController)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                           Expanded(child: _buildTextField('Email Contato', _emailCondoController)),
                           const SizedBox(width: 10),
                           Expanded(child: _buildTextField('Telefone', _telefoneCondoController)),
                        ]),

                        const Divider(height: 20),
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

                        const Divider(height: 20),
                        const Text("3. Síndico Responsável", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 5),
                        
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: Colors.green[50], border: Border.all(color: Colors.green)),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Colors.green),
                              const SizedBox(width: 10),
                              Text(
                                _nomeSindicoVinculado != null 
                                ? "Síndico Atual: $_nomeSindicoVinculado" 
                                : "Nenhum síndico vinculado.",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900], fontSize: 16)
                              ),
                            ],
                          ),
                        ),

                        if(item != null) ...[
                             TextField(
                                controller: _buscaUserController,
                                decoration: const InputDecoration(labelText: 'Buscar SÍNDICO (CPF/Nome)', suffixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                                onChanged: (val) { if (val.length >= 3) _buscarSindicoNoBanco(val).then((_) => setStateModal((){})); },
                             ),
                             if(_buscandoUser) const LinearProgressIndicator(),
                             if (_resultadosBusca.isNotEmpty)
                                Container(height: 150, decoration: BoxDecoration(border: Border.all(color: Colors.grey)), child: ListView.builder(itemCount: _resultadosBusca.length, itemBuilder: (ctx, i) {
                                    final u = _resultadosBusca[i];
                                    return ListTile(
                                      dense: true, 
                                      leading: const Icon(Icons.person_add),
                                      title: Text("${u['nome']} (${u['tipo']})"), 
                                      subtitle: Text("CPF: ${u['cpf']}"), 
                                      trailing: ElevatedButton(
                                        onPressed: () { _vincularNaHora(u, item['id']).then((_) => setStateModal((){})); }, 
                                        child: const Text("VINCULAR")
                                      )
                                    );
                                })),
                        ] else const Text("Salve o condomínio primeiro para vincular o síndico.", style: TextStyle(color: Colors.red)),
                        
                        const Divider(height: 20),
                        const Text("4. Configurações", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        Row(children: [Expanded(child: _buildTextField('R\$ Água', _precoAguaController)), const SizedBox(width: 5), Expanded(child: _buildTextField('R\$ Gás', _precoGasController)), const SizedBox(width: 5), Expanded(child: _buildTextField('Dia Corte', _diaCorteController))]),
                    ]))),
                actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () => _salvarCondominio(idEdicao: item?['id']), child: const Text('SALVAR DADOS')),
                ],
            );
        });
    });
  }

  Widget _buildTextField(String l, TextEditingController c) => TextField(controller: c, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), isDense: true));

  @override
  Widget build(BuildContext context) {
    bool podeEditar = (widget.usuarioLogado == null || widget.usuarioLogado!['nivel'] == 'master');
    return Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Gestão de Condomínios', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold)),
            if (podeEditar) ElevatedButton.icon(onPressed: () => _abrirModal(), icon: const Icon(Icons.add), label: const Text('NOVO'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)),
        ]),
        const SizedBox(height: 20),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: _condominios.length, itemBuilder: (ctx, index) {
            final c = _condominios[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    ListTile(
                        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.apartment, size: 30, color: Colors.blue)),
                        title: Text(c['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CNPJ: ${c['cnpj']}'),
                            const SizedBox(height: 5),
                            Row(children: [
                                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 5),
                                Text('Síndico: ${c['nome_sindico'] ?? 'Não definido'}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
                            ]),
                            Text('Água: R\$ ${c['valor_m3_agua']} | Gás: R\$ ${c['valor_m3_gas']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (podeEditar) IconButton(icon: const Icon(Icons.edit, color: Colors.orange), tooltip: "Editar", onPressed: () => _abrirModal(item: c)),
                            if (podeEditar) IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red), 
                              tooltip: "Excluir",
                              onPressed: () {
                                showDialog(context: context, builder: (ctx) => AlertDialog(
                                  title: const Text('ATENÇÃO'),
                                  content: Text('Excluir ${c['nome']}?\nIsso apagará tudo!'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                                    TextButton(onPressed: () { Navigator.pop(ctx); _excluir(c['id']); }, child: const Text('EXCLUIR', style: TextStyle(color: Colors.red))),
                                  ],
                                ));
                              }
                            ),
                            const VerticalDivider(),
                            IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalheCondominioWeb(condominio: c)))),
                        ]),
                    ),
                  ],
                ),
              ),
            );
        })),
    ]);
  }
}