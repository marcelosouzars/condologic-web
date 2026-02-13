import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service_web.dart';
import 'detalhe_bloco_web.dart';

class DetalheCondominioWeb extends StatefulWidget {
  final Map<String, dynamic> condominio;

  const DetalheCondominioWeb({super.key, required this.condominio});
  
  @override
  State<DetalheCondominioWeb> createState() => _DetalheCondominioWebState();
}

class _DetalheCondominioWebState extends State<DetalheCondominioWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  
  List<dynamic> _blocos = [];
  bool _isLoading = true;
  
  // Controllers para o Bloco Simples (Modo Manual)
  final _nomeBlocoController = TextEditingController();

  // Controllers para a MÁQUINA DE ESTRUTURA (Wizard Automático)
  final _nomeBlocoWizardController = TextEditingController();
  final _qtdAndaresController = TextEditingController();
  final _qtdAptosController = TextEditingController();
  final _inicioNumeracaoController = TextEditingController(text: "1"); // Padrão começa no 1 (ex: 101)
  
  // Checkboxes
  bool _temAgua = true;
  bool _temGas = false;
  bool _temAguaQuente = false; // <<< NOVO

  @override
  void initState() {
    super.initState();
    _carregarBlocos();
  }

  Future<void> _carregarBlocos() async {
    setState(() => _isLoading = true);
    try {
      final blocos = await _apiService.getBlocos(widget.condominio['id']);
      setState(() {
        _blocos = blocos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- MODO 1: CRIAR BLOCO VAZIO (Simples) ---
  Future<void> _salvarBlocoSimples() async {
    if (_nomeBlocoController.text.isEmpty) return;
    try {
      await _apiService.criarBloco(widget.condominio['id'], _nomeBlocoController.text);
      if (mounted) {
        Navigator.pop(context);
        _nomeBlocoController.clear();
        _carregarBlocos();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bloco criado com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  // --- MODO 2: A MÁQUINA DE ESTRUTURA (Complexo) ---
  Future<void> _executarWizard() async {
    if (_nomeBlocoWizardController.text.isEmpty || _qtdAndaresController.text.isEmpty || _qtdAptosController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos do Wizard!')));
       return;
    }

    Navigator.pop(context); 
    setState(() => _isLoading = true);

    try {
      List<String> medidores = [];
      if (_temAgua) medidores.add('agua_fria');
      if (_temGas) medidores.add('gas');
      if (_temAguaQuente) medidores.add('agua_quente'); // <<<

      await _apiService.gerarEstruturaCompleta({
        'tenant_id': widget.condominio['id'],
        'nome_bloco': _nomeBlocoWizardController.text,
        'qtde_andares': int.parse(_qtdAndaresController.text),
        'unidades_por_andar': int.parse(_qtdAptosController.text),
        'inicio_numeracao': int.tryParse(_inicioNumeracaoController.text) ?? 1, // <<<
        'criar_medidores': medidores
      });

      _nomeBlocoWizardController.clear();
      _qtdAndaresController.clear();
      _qtdAptosController.clear();
      _inicioNumeracaoController.text = "1";
      
      await _carregarBlocos();
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SUCESSO! O Bloco e todas as unidades foram gerados automaticamente.'), 
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          )
        );
      }

    } catch (e) {
      setState(() => _isLoading = false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar estrutura: $e'), backgroundColor: Colors.red));
    }
  }

  void _abrirModalCriacao() {
    _nomeBlocoController.text = "";
    _nomeBlocoWizardController.text = "";
    _qtdAndaresController.text = "";
    _qtdAptosController.text = "";
    _inicioNumeracaoController.text = "1";
    _temAgua = true;
    _temGas = false;
    _temAguaQuente = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return DefaultTabController(
              length: 2,
              child: AlertDialog(
                title: const Text('Adicionar Nova Estrutura'),
                content: SizedBox(
                  width: 600, // Aumentei um pouco a largura
                  height: 500,
                  child: Column(
                    children: [
                      const TabBar(
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          Tab(icon: Icon(Icons.flash_on), text: "Automático (Wizard)"),
                          Tab(icon: Icon(Icons.crop_square), text: "Bloco Vazio"),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // --- ABA 1: WIZARD (AUTOMÁTICO) ---
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      color: Colors.blue[50],
                                      child: const Text("Cria o Bloco, Andares e Apartamentos de uma só vez.", style: TextStyle(fontSize: 12, color: Colors.black87)),
                                    ),
                                    const SizedBox(height: 15),
                                    TextField(
                                      controller: _nomeBlocoWizardController,
                                      decoration: const InputDecoration(labelText: 'Nome do Bloco (Ex: Torre A)', border: OutlineInputBorder(), isDense: true),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(child: TextField(controller: _qtdAndaresController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qtd Andares', hintText: 'Ex: 13', border: OutlineInputBorder(), isDense: true))),
                                        const SizedBox(width: 10),
                                        Expanded(child: TextField(controller: _qtdAptosController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Aptos/Andar', hintText: 'Ex: 4', border: OutlineInputBorder(), isDense: true))),
                                        const SizedBox(width: 10),
                                        // CAMPO NOVO: NUMERO INICIAL
                                        Expanded(child: TextField(controller: _inicioNumeracaoController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Início (Sufixo)', hintText: 'Ex: 1 (gera 101)', border: OutlineInputBorder(), isDense: true))),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    const Text("Ex: Se 'Início' for 1, gera 101, 102... Se for 5, gera 105, 106...", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    
                                    const SizedBox(height: 15),
                                    const Text("Quais medidores instalar em todas as unidades?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Row(
                                      children: [
                                        Checkbox(value: _temAgua, onChanged: (v) => setStateModal(() => _temAgua = v!)),
                                        const Text("Água Fria"),
                                        const SizedBox(width: 10),
                                        Checkbox(value: _temAguaQuente, onChanged: (v) => setStateModal(() => _temAguaQuente = v!)),
                                        const Text("Água Quente"),
                                        const SizedBox(width: 10),
                                        Checkbox(value: _temGas, onChanged: (v) => setStateModal(() => _temGas = v!)),
                                        const Text("Gás"),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _executarWizard,
                                        icon: const Icon(Icons.auto_awesome, color: Colors.white),
                                        label: const Text('GERAR ESTRUTURA COMPLETA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], padding: const EdgeInsets.symmetric(vertical: 18)),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),

                            // --- ABA 2: SIMPLES (BLOCO VAZIO) ---
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.architecture, size: 50, color: Colors.grey),
                                  const SizedBox(height: 20),
                                  const Text("Cria apenas o nome do bloco.\nVocê terá que adicionar as unidades manualmente depois.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 20),
                                  TextField(
                                    controller: _nomeBlocoController,
                                    decoration: const InputDecoration(labelText: 'Nome do Bloco', border: OutlineInputBorder()),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: _salvarBlocoSimples,
                                    child: const Text('CRIAR BLOCO VAZIO'),
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
        title: Text(widget.condominio['nome'], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estrutura do Condomínio',
                  style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                ElevatedButton.icon(
                  onPressed: _abrirModalCriacao,
                  icon: const Icon(Icons.add_business, color: Colors.white),
                  label: const Text('ADICIONAR BLOCO', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], padding: const EdgeInsets.all(16)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _blocos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.domain_disabled, size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 10),
                              const Text('Nenhum bloco cadastrado.'),
                              const SizedBox(height: 5),
                              const Text('Clique em ADICIONAR BLOCO para começar.', style: TextStyle(color: Colors.blue)),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 1.4,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _blocos.length,
                          itemBuilder: (context, index) {
                            final bloco = _blocos[index];
                            return Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetalheBlocoWeb(
                                        bloco: bloco, 
                                        condominio: widget.condominio
                                      ),
                                    ),
                                  ).then((_) => _carregarBlocos());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: Colors.blue[50],
                                        child: Icon(Icons.apartment, size: 30, color: Colors.blue[800]),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        bloco['nome'],
                                        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 5),
                                      const Text('Gerenciar Unidades', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
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