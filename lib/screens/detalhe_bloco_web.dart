// ==========================================>>> detalhe_bloco_web.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service_web.dart';
import 'detalhe_unidade_web.dart'; 

class DetalheBlocoWeb extends StatefulWidget {
  final Map<String, dynamic> bloco;
  final Map<String, dynamic> condominio;

  const DetalheBlocoWeb({super.key, required this.bloco, required this.condominio});

  @override
  State<DetalheBlocoWeb> createState() => _DetalheBlocoWebState();
}

class _DetalheBlocoWebState extends State<DetalheBlocoWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  List<dynamic> _unidades = [];
  bool _isLoading = true;

  // --- CONTROLADOR DA CRIAÇÃO MANUAL ---
  final _identificacaoManualController = TextEditingController();
  final _andarManualController = TextEditingController();

  // --- CONTROLADADORES DO GERADOR INTELIGENTE ---
  final _qtdeAndaresController = TextEditingController(text: "13"); 
  final _aptosPorAndarController = TextEditingController(text: "12"); 
  String _padraoNumeracao = 'por_andar'; 
  int _andarInicial = 1; // 0 = Térreo, 1 = 1º Andar
  
  // --- CHECKBOXES DE MEDIDORES ---
  bool _temAguaFria = true; 
  bool _temGas = true;
  bool _temAguaQuente = true;

  @override
  void initState() {
    super.initState();
    _carregarUnidades();
  }

  Future<void> _carregarUnidades() async {
    setState(() => _isLoading = true);
    try {
      final unidadesRaw = await _apiService.getUnidadesPorBloco(widget.bloco['id']);
      List<dynamic> unidadesOrdenadas = List.from(unidadesRaw);

      // >>> MÁGICA DA ORDENAÇÃO NATURAL CRESCENTE <<<
      // Essa função ensina o sistema a ordenar números de forma humana (1, 2, 3... 10, 11)
      // mesmo quando eles estão misturados com textos (Ex: T01, COB-01).
      unidadesOrdenadas.sort((a, b) {
        String padNumbers(String input) {
          return input.replaceAllMapped(RegExp(r'\d+'), (Match m) => m[0]!.padLeft(10, '0'));
        }
        return padNumbers(a['identificacao'].toString()).compareTo(padNumbers(b['identificacao'].toString()));
      });

      setState(() {
        _unidades = unidadesOrdenadas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ======================================================
  // MODO 1: GERADOR INTELIGENTE
  // ======================================================
  Future<void> _executarGeracaoInteligente() async {
    if (_qtdeAndaresController.text.isEmpty || _aptosPorAndarController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha a quantidade de andares e apartamentos.')));
      return;
    }
    
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.white)));
    
    try {
      List<String> medidores = [];
      if (_temAguaFria) medidores.add('agua_fria');
      if (_temGas) medidores.add('gas');
      if (_temAguaQuente) medidores.add('agua_quente');

      await _apiService.gerarUnidadesInteligente({
        'tenant_id': widget.condominio['id'],
        'bloco_id': widget.bloco['id'],
        'padrao_numeracao': _padraoNumeracao,
        'andar_inicial': _andarInicial,
        'qtde_andares': int.parse(_qtdeAndaresController.text),
        'aptos_por_andar': int.parse(_aptosPorAndarController.text),
        'criar_medidores': medidores
      });

      if (mounted) {
        Navigator.pop(context); // Fecha loading
        Navigator.pop(context); // Fecha modal
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toda a estrutura foi gerada com sucesso!'), backgroundColor: Colors.green));
        _carregarUnidades();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ======================================================
  // MODO 2: CRIAÇÃO MANUAL AVULSA
  // ======================================================
  Future<void> _salvarUnidadeManual() async {
    if (_identificacaoManualController.text.isEmpty) return;
    try {
      List<String> medidores = [];
      if (_temAguaFria) medidores.add('agua_fria');
      if (_temGas) medidores.add('gas');
      if (_temAguaQuente) medidores.add('agua_quente');

      await _apiService.criarUnidade({
        'tenant_id': widget.condominio['id'],
        'bloco_id': widget.bloco['id'],
        'identificacao': _identificacaoManualController.text,
        'andar': _andarManualController.text.isEmpty ? 'Térreo' : _andarManualController.text,
        'criar_medidores': medidores
      });

      if (mounted) {
        Navigator.pop(context);
        _identificacaoManualController.clear();
        _carregarUnidades();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unidade avulsa criada!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  // --- MODAL DE CRIAÇÃO ---
  void _abrirModalCriacao() {
    _identificacaoManualController.clear();
    _andarManualController.clear();
    _temAguaFria = true; _temGas = true; _temAguaQuente = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return DefaultTabController(
              length: 2,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                title: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.blue[900]),
                    const SizedBox(width: 10),
                    const Text('Criar Unidades'),
                  ],
                ),
                content: SizedBox(
                  width: 600,
                  height: 500,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.blue[900],
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.blue[900],
                        tabs: const [
                          Tab(icon: Icon(Icons.flash_on), text: "Gerador Inteligente"),
                          Tab(icon: Icon(Icons.person), text: "Criação Manual (Avulsa)"),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // ============================================
                            // ABA 1: GERADOR INTELIGENTE
                            // ============================================
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("1. Selecione os Medidores de cada Apartamento", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                    Row(
                                      children: [
                                        Expanded(child: CheckboxListTile(title: const Text("Água Fria"), value: _temAguaFria, onChanged: (v) => setStateModal(() => _temAguaFria = v!))),
                                        Expanded(child: CheckboxListTile(title: const Text("Gás"), value: _temGas, onChanged: (v) => setStateModal(() => _temGas = v!))),
                                        Expanded(child: CheckboxListTile(title: const Text("Quente"), value: _temAguaQuente, onChanged: (v) => setStateModal(() => _temAguaQuente = v!))),
                                      ],
                                    ),
                                    const Divider(),
                                    const SizedBox(height: 10),

                                    const Text("2. Estrutura do Prédio", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(child: TextField(controller: _qtdeAndaresController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qtde. de Andares (Ex: 13)', border: OutlineInputBorder()))),
                                        const SizedBox(width: 15),
                                        Expanded(child: TextField(controller: _aptosPorAndarController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Aptos por Andar (Ex: 12)', border: OutlineInputBorder()))),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    const Text("3. Regra de Numeração", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<int>(
                                            value: _andarInicial,
                                            decoration: const InputDecoration(labelText: 'Inicia em qual andar?', border: OutlineInputBorder()),
                                            items: const [
                                              DropdownMenuItem(value: 0, child: Text("Térreo (Inicia no Térreo)")),
                                              DropdownMenuItem(value: 1, child: Text("1º Andar (Inicia no 1º)")),
                                              DropdownMenuItem(value: 2, child: Text("2º Andar (Inicia no 2º)")),
                                            ],
                                            onChanged: (v) => setStateModal(() => _andarInicial = v!),
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: _padraoNumeracao,
                                            decoration: const InputDecoration(labelText: 'Padrão dos Números', border: OutlineInputBorder()),
                                            items: const [
                                              DropdownMenuItem(value: 'por_andar', child: Text("Por Andar (101, 102 / 201...)")),
                                              DropdownMenuItem(value: 'continuo', child: Text("Contínuo (1, 2, 3, 4...)")),
                                            ],
                                            onChanged: (v) => setStateModal(() => _padraoNumeracao = v!),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 30),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        onPressed: _executarGeracaoInteligente,
                                        icon: const Icon(Icons.build, color: Colors.white),
                                        label: const Text("GERAR PRÉDIO COMPLETO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            
                            // ============================================
                            // ABA 2: CRIAÇÃO MANUAL AVULSA
                            // ============================================
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Para adicionar unidades fora do padrão (Ex: Casa de Máquinas, Cobertura).", style: TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 20),
                                  TextField(controller: _identificacaoManualController, decoration: const InputDecoration(labelText: 'Identificação (Ex: COB-01)', border: OutlineInputBorder())),
                                  const SizedBox(height: 15),
                                  TextField(controller: _andarManualController, decoration: const InputDecoration(labelText: 'Andar (Ex: Cobertura)', border: OutlineInputBorder())),
                                  const SizedBox(height: 15),
                                  const Text("Medidores:", style: TextStyle(fontWeight: FontWeight.bold)),
                                  Row(
                                    children: [
                                      Expanded(child: CheckboxListTile(title: const Text("Água Fria", style: TextStyle(fontSize: 12)), value: _temAguaFria, onChanged: (v) => setStateModal(() => _temAguaFria = v!))),
                                      Expanded(child: CheckboxListTile(title: const Text("Gás", style: TextStyle(fontSize: 12)), value: _temGas, onChanged: (v) => setStateModal(() => _temGas = v!))),
                                      Expanded(child: CheckboxListTile(title: const Text("Quente", style: TextStyle(fontSize: 12)), value: _temAguaQuente, onChanged: (v) => setStateModal(() => _temAguaQuente = v!))),
                                    ],
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed: _salvarUnidadeManual, 
                                      icon: const Icon(Icons.add, color: Colors.white),
                                      label: const Text("ADICIONAR UNIDADE", style: TextStyle(color: Colors.white)),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("FECHAR", style: TextStyle(color: Colors.grey))),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text("${widget.condominio['nome']} > ${widget.bloco['nome']}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --- CARTÃO DE AÇÃO SUPERIOR ---
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _abrirModalCriacao,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_business, color: Colors.blue[800], size: 40),
                          const SizedBox(width: 15),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("GERENCIAR UNIDADES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              Text("Criar Estrutura Inteligente ou Adição Manual", style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),

            // --- GRID DE UNIDADES ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _unidades.isEmpty
                      ? const Center(child: Text("Nenhuma unidade cadastrada. Use o botão acima para gerar a estrutura.", style: TextStyle(fontSize: 16)))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 140, 
                            childAspectRatio: 1.2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _unidades.length,
                          itemBuilder: (context, index) {
                            final u = _unidades[index];
                            
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(
                                    builder: (_) => DetalheUnidadeWeb(unidade: u, condominio: widget.condominio)
                                  )
                                );
                              },
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      u['identificacao'], 
                                      style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900])
                                    ),
                                    const SizedBox(height: 4),
                                    Text(u['andar'] ?? '-', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                                      child: Text('${u['total_medidores']} Med.', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 5),
                                    const Text('Ver relógios', style: TextStyle(color: Colors.blue, fontSize: 10, decoration: TextDecoration.underline)),
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