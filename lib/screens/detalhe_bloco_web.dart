import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service_web.dart';
import 'detalhe_unidade_web.dart'; // <--- IMPORT DA NOVA TELA ADICIONADO AQUI

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

  // --- CONTROLADORES DO GERADOR EM LOTE ---
  final _andarController = TextEditingController();
  final _inicioController = TextEditingController();
  final _fimController = TextEditingController();
  
  // --- CONTROLADOR DA CRIAÇÃO MANUAL ---
  final _identificacaoManualController = TextEditingController();

  // --- CHECKBOXES DE MEDIDORES ---
  bool _temAguaFria = true; 
  bool _temGas = false;
  bool _temAguaQuente = false; // <--- NOVO: ÁGUA QUENTE

  @override
  void initState() {
    super.initState();
    _carregarUnidades();
  }

  Future<void> _carregarUnidades() async {
    setState(() => _isLoading = true);
    try {
      final unidades = await _apiService.getUnidadesPorBloco(widget.bloco['id']);
      setState(() {
        _unidades = unidades;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ======================================================
  // LÓGICA 1: GERADOR EM LOTE (WIZARD)
  // ======================================================
  Future<void> _executarGeracaoEmLote() async {
    if (_inicioController.text.isEmpty || _fimController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o número inicial e final.')));
      return;
    }
    
    // Mostra loading
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      List<String> medidores = [];
      if (_temAguaFria) medidores.add('agua_fria');
      if (_temGas) medidores.add('gas');
      if (_temAguaQuente) medidores.add('agua_quente'); // <--- ENVIANDO ÁGUA QUENTE

      await _apiService.gerarUnidadesLote({
        'tenant_id': widget.condominio['id'],
        'bloco_id': widget.bloco['id'],
        'andar': _andarController.text.isEmpty ? 'Andar Padrão' : _andarController.text,
        'inicio': int.parse(_inicioController.text),
        'fim': int.parse(_fimController.text),
        'criar_medidores': medidores
      });

      if (mounted) {
        Navigator.pop(context); // Fecha loading
        Navigator.pop(context); // Fecha o modal
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unidades geradas com sucesso!'), backgroundColor: Colors.green));
        _carregarUnidades(); // Atualiza tela
        
        // Limpa campos
        _inicioController.clear();
        _fimController.clear();
        _andarController.clear();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ======================================================
  // LÓGICA 2: CRIAÇÃO MANUAL (UM POR UM)
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
        'criar_medidores': medidores
      });

      if (mounted) {
        Navigator.pop(context);
        _identificacaoManualController.clear();
        _carregarUnidades();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unidade criada!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  // --- MODAL DO WIZARD (O GRANDÃO) ---
  void _abrirModalWizard() {
    _andarController.text = "";
    _inicioController.text = "";
    _fimController.text = "";
    // Reseta checkboxes
    _temAguaFria = true; _temGas = false; _temAguaQuente = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.blue),
                  const SizedBox(width: 10),
                  const Text('Gerador de Unidades'),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 450,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Passo 1: O que vamos medir?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: CheckboxListTile(title: const Text("Água Fria"), value: _temAguaFria, onChanged: (v) => setStateModal(() => _temAguaFria = v!))),
                          Expanded(child: CheckboxListTile(title: const Text("Gás"), value: _temGas, onChanged: (v) => setStateModal(() => _temGas = v!))),
                        ],
                      ),
                      CheckboxListTile(title: const Text("Água Quente"), value: _temAguaQuente, onChanged: (v) => setStateModal(() => _temAguaQuente = v!)),
                      
                      const Divider(height: 30),

                      const Text("Passo 2: Qual o Andar/Grupo?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _andarController,
                        decoration: const InputDecoration(labelText: 'Ex: 1º Andar, Térreo...', border: OutlineInputBorder(), prefixIcon: Icon(Icons.layers)),
                      ),

                      const Divider(height: 30),

                      const Text("Passo 3: Intervalo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _inicioController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'De (Início)', hintText: 'Ex: 101', border: OutlineInputBorder()))),
                          const SizedBox(width: 15),
                          const Icon(Icons.arrow_forward),
                          const SizedBox(width: 15),
                          Expanded(child: TextField(controller: _fimController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Até (Final)', hintText: 'Ex: 110', border: OutlineInputBorder()))),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text("O sistema criará todas as unidades entre esses números.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
                ElevatedButton.icon(
                  onPressed: _executarGeracaoEmLote,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text("GERAR AGORA", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MODAL MANUAL (O SIMPLES) ---
  void _abrirModalManual() {
    _identificacaoManualController.text = "";
    _temAguaFria = true; _temGas = false; _temAguaQuente = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: const Text('Nova Unidade (Individual)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _identificacaoManualController, decoration: const InputDecoration(labelText: 'Identificação (Ex: 12B)', border: OutlineInputBorder())),
              const SizedBox(height: 15),
              CheckboxListTile(title: const Text("Água Fria"), value: _temAguaFria, onChanged: (v) => setStateModal(() => _temAguaFria = v!)),
              CheckboxListTile(title: const Text("Gás"), value: _temGas, onChanged: (v) => setStateModal(() => _temGas = v!)),
              CheckboxListTile(title: const Text("Água Quente"), value: _temAguaQuente, onChanged: (v) => setStateModal(() => _temAguaQuente = v!)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: _salvarUnidadeManual, child: const Text('Salvar')),
          ],
        ),
      ),
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
            // --- CARTÕES DE AÇÃO SUPERIOR ---
            Row(
              children: [
                // BOTÃO WIZARD (GRANDE)
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: _abrirModalWizard,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.blue[800], size: 40),
                          const SizedBox(width: 15),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Gerador em Lote", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("Criar várias unidades (Ex: 101 ao 110)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // BOTÃO MANUAL (PEQUENO)
                Expanded(
                  flex: 1,
                  child: InkWell(
                    onTap: _abrirModalManual,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.withOpacity(0.3))),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.green),
                          SizedBox(width: 10),
                          Text("Adicionar Manual", style: TextStyle(fontWeight: FontWeight.bold)),
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
                      ? const Center(child: Text("Nenhuma unidade cadastrada."))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            // [VISUAL] Aqui eu diminuí para 140 para os cards ficarem menores e caber mais
                            maxCrossAxisExtent: 140, 
                            childAspectRatio: 1.2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _unidades.length,
                          itemBuilder: (context, index) {
                            final u = _unidades[index];
                            
                            // ==========================================================
                            // INKWELL ADICIONADO AQUI! AGORA O CARD É CLICÁVEL
                            // ==========================================================
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
                            // ==========================================================
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}