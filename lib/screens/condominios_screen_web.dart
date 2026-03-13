import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service_web.dart';
import 'detalhe_condominio_web.dart';

class CondominiosScreenWeb extends StatefulWidget {
  // <--- CORREÇÃO AQUI: Tipagem idêntica à que a tela principal envia
  final Map<String, dynamic>? usuarioLogado; 
  const CondominiosScreenWeb({super.key, required this.usuarioLogado});

  @override
  State<CondominiosScreenWeb> createState() => _CondominiosScreenWebState();
}

class _CondominiosScreenWebState extends State<CondominiosScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  List<dynamic> _condominios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarCondominios();
  }

  Future<void> _carregarCondominios() async {
    setState(() => _isLoading = true);
    try {
      final dados = await _apiService.getCondominios();
      setState(() {
        _condominios = dados;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarMensagem('Erro ao carregar condomínios: $e', isError: true);
    }
  }

  void _mostrarMensagem(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================================
  // MODAL DE INCLUSÃO / EDIÇÃO (COM BLINDAGEM DE VÍRGULAS)
  // =========================================================================
  void _abrirModal({Map? item}) {
    final bool isEdicao = item != null;
    final _formKey = GlobalKey<FormState>();

    // Controladores de Texto
    final _nomeCtrl = TextEditingController(text: item?['nome'] ?? '');
    final _cnpjCtrl = TextEditingController(text: item?['cnpj'] ?? '');
    final _enderecoCtrl = TextEditingController(text: item?['endereco_completo'] ?? '');
    final _sindicoNomeCtrl = TextEditingController(text: item?['nome_sindico'] ?? '');
    final _sindicoEmailCtrl = TextEditingController(text: item?['email_sindico'] ?? '');
    final _sindicoTelCtrl = TextEditingController(text: item?['telefone_sindico'] ?? '');
    
    // Controladores Financeiros (Trazendo do banco já formatados)
    final _aguaFriaCtrl = TextEditingController(text: item?['valor_m3_agua']?.toString() ?? '0.00');
    final _aguaQuenteCtrl = TextEditingController(text: item?['valor_m3_agua_quente']?.toString() ?? '0.00');
    final _gasCtrl = TextEditingController(text: item?['valor_m3_gas']?.toString() ?? '0.00');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            isEdicao ? 'Editar Condomínio' : 'Novo Condomínio',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.blue[900]),
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Dados Gerais", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nomeCtrl,
                      decoration: const InputDecoration(labelText: 'Nome do Condomínio', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _cnpjCtrl,
                            decoration: const InputDecoration(labelText: 'CNPJ', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _enderecoCtrl,
                            decoration: const InputDecoration(labelText: 'Endereço Completo', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text("Contato do Síndico / Gestor", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _sindicoNomeCtrl,
                      decoration: const InputDecoration(labelText: 'Nome do Síndico', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sindicoTelCtrl,
                            decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _sindicoEmailCtrl,
                            decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text("Tarifas de Consumo (R\$ / m³)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _aguaFriaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Água Fria (R\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.water_drop, color: Colors.blue)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _aguaQuenteCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Água Quente (R\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.hot_tub, color: Colors.red)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _gasCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Gás (R\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_fire_department, color: Colors.orange)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    // Troca vírgula por ponto antes de converter!
                    double valAgua = double.tryParse(_aguaFriaCtrl.text.replaceAll(',', '.')) ?? 0.0;
                    double valAguaQuente = double.tryParse(_aguaQuenteCtrl.text.replaceAll(',', '.')) ?? 0.0;
                    double valGas = double.tryParse(_gasCtrl.text.replaceAll(',', '.')) ?? 0.0;

                    final dados = {
                      'nome': _nomeCtrl.text,
                      'cnpj': _cnpjCtrl.text,
                      'endereco_completo': _enderecoCtrl.text,
                      'nome_sindico': _sindicoNomeCtrl.text,
                      'telefone_sindico': _sindicoTelCtrl.text,
                      'email_sindico': _sindicoEmailCtrl.text,
                      'valor_m3_agua': valAgua,
                      'valor_m3_agua_quente': valAguaQuente,
                      'valor_m3_gas': valGas,
                    };

                    if (isEdicao) {
                      await _apiService.editarCondominio(item['id'], dados);
                      _mostrarMensagem('Condomínio atualizado com sucesso!');
                    } else {
                      await _apiService.criarCondominio(dados);
                      _mostrarMensagem('Condomínio criado com sucesso!');
                    }

                    Navigator.pop(context);
                    _carregarCondominios();
                  } catch (e) {
                    _mostrarMensagem('Erro ao salvar: $e', isError: true);
                  }
                }
              },
              child: const Text('SALVAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // EXCLUSÃO COM TRAVA DE SEGURANÇA (APENAS MASTER)
  // =========================================================================
  void _confirmarExclusao(Map item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Condomínio?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('Tem certeza que deseja excluir o condomínio "${item['nome']}"?\n\nIsso apagará TODOS os blocos, unidades e leituras vinculadas a ele. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                // CORRIGIDO AQUI: A interrogação (?) protege caso a internet caia
                await _apiService.excluirCondominio(item['id'], widget.usuarioLogado?['nivel_acesso'] ?? '');
                _mostrarMensagem('Condomínio excluído com sucesso.');
                _carregarCondominios();
              } catch (e) {
                _mostrarMensagem('Erro: $e', isError: true);
              }
            },
            child: const Text('Sim, Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // CORRIGIDO AQUI TAMBÉM: A interrogação (?) protege o acesso ao Map
    final bool podeEditar = widget.usuarioLogado?['nivel_acesso'] == 'master';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gestão de Condomínios', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
            if (podeEditar)
              ElevatedButton.icon(
                onPressed: () => _abrirModal(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('INCLUIR CONDOMÍNIO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _condominios.isEmpty
                  ? const Center(child: Text("Nenhum condomínio cadastrado."))
                  : ListView.builder(
                      itemCount: _condominios.length,
                      itemBuilder: (context, index) {
                        final c = _condominios[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(15),
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: Icon(Icons.apartment, color: Colors.blue[900]),
                            ),
                            title: Text(c['nome'] ?? 'Sem Nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                Text('Síndico: ${c['nome_sindico'] ?? 'Não informado'} | Tel: ${c['telefone_sindico'] ?? '-'}'),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text('Água: R\$ ${c['valor_m3_agua'] ?? '0.00'}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(width: 10),
                                    Text('Água Quente: R\$ ${c['valor_m3_agua_quente'] ?? '0.00'}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(width: 10),
                                    Text('Gás: R\$ ${c['valor_m3_gas'] ?? '0.00'}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (podeEditar)
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.orange),
                                    tooltip: "Editar Condomínio",
                                    onPressed: () => _abrirModal(item: c),
                                  ),
                                if (podeEditar)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: "Excluir Condomínio",
                                    onPressed: () => _confirmarExclusao(c),
                                  ),
                                const SizedBox(width: 10),
                                const VerticalDivider(indent: 10, endIndent: 10),
                                Tooltip(
                                  message: "Abrir Blocos e Unidades",
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => DetalheCondominioWeb(condominio: c)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}