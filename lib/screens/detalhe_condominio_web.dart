// ==========================================>>> detalhe_condominio_web.dart
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
  
  // Controllers do Gerador Inteligente
  final _nomeBlocoController = TextEditingController();
  final _qtdeAndaresController = TextEditingController(text: "12");
  final _aptosPorAndarController = TextEditingController(text: "4"); 
  final _sufixoInicialController = TextEditingController(text: "1");
  final _andarInicialController = TextEditingController(text: "1");
  
  String _padraoNumeracao = 'por_andar';
  bool _temAguaFria = true; 
  bool _temGas = true;
  bool _temAguaQuente = true;
  bool _gerarUnidades = true; // Permite criar o bloco vazio se desmarcado

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

  Future<void> _salvarBloco() async {
    if (_nomeBlocoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o nome do bloco.')));
      return;
    }

    if (_gerarUnidades && (_qtdeAndaresController.text.isEmpty || _aptosPorAndarController.text.isEmpty || _sufixoInicialController.text.isEmpty || _andarInicialController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha as regras de numeração e andares.')));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.white)));
    
    try {
      // 1. Cria o bloco e recebe o ID dele de volta
      int blocoId = await _apiService.criarBloco(widget.condominio['id'], _nomeBlocoController.text);

      // 2. Se for para gerar a estrutura inteligente junto
      if (_gerarUnidades) {
        List<String> medidores = [];
        if (_temAguaFria) medidores.add('agua_fria');
        if (_temGas) medidores.add('gas');
        if (_temAguaQuente) medidores.add('agua_quente');

        await _apiService.gerarUnidadesInteligente({
          'tenant_id': widget.condominio['id'],
          'bloco_id': blocoId,
          'padrao_numeracao': _padraoNumeracao,
          'andar_inicial': int.parse(_andarInicialController.text),
          'qtde_andares': int.parse(_qtdeAndaresController.text),
          'aptos_por_andar': int.parse(_aptosPorAndarController.text),
          'sufixo_inicial': int.parse(_sufixoInicialController.text), 
          'criar_medidores': medidores
        });
      }

      if (mounted) {
        Navigator.pop(context); // Fecha loading
        Navigator.pop(context); // Fecha modal
        _nomeBlocoController.clear();
        _carregarBlocos(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bloco e estrutura criados com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fecha loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _abrirModalBloco() {
    // Reset defaults ao abrir
    _nomeBlocoController.clear();
    _qtdeAndaresController.text = "12";
    _aptosPorAndarController.text = "4";
    _sufixoInicialController.text = "1";
    _andarInicialController.text = "1";
    _padraoNumeracao = 'por_andar';
    _temAguaFria = true;
    _temGas = true;
    _temAguaQuente = true;
    _gerarUnidades = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  Icon(Icons.domain_add, color: Colors.blue[800]),
                  const SizedBox(width: 10),
                  const Text('Criar Bloco / Torre'),
                ],
              ),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("1. Identificação", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nomeBlocoController,
                        decoration: const InputDecoration(labelText: 'Nome do Bloco (Ex: Torre A)', border: OutlineInputBorder()),
                      ),
                      
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),

                      SwitchListTile(
                        title: const Text("Criar unidades automaticamente agora?", style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("O Gerador Inteligente fará o trabalho pesado por você."),
                        value: _gerarUnidades,
                        activeColor: Colors.blue[800],
                        onChanged: (val) => setStateModal(() => _gerarUnidades = val),
                      ),

                      if (_gerarUnidades) ...[
                        const SizedBox(height: 15),
                        const Text("2. Selecione os Medidores de cada Apartamento", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        Row(
                          children: [
                            Expanded(child: CheckboxListTile(title: const Text("Água Fria"), value: _temAguaFria, onChanged: (v) => setStateModal(() => _temAguaFria = v!))),
                            Expanded(child: CheckboxListTile(title: const Text("Gás"), value: _temGas, onChanged: (v) => setStateModal(() => _temGas = v!))),
                            Expanded(child: CheckboxListTile(title: const Text("Quente"), value: _temAguaQuente, onChanged: (v) => setStateModal(() => _temAguaQuente = v!))),
                          ],
                        ),
                        
                        const SizedBox(height: 15),
                        const Text("3. Estrutura do Prédio", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _qtdeAndaresController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qtde. de Andares (Ex: 12)', border: OutlineInputBorder()))),
                            const SizedBox(width: 15),
                            Expanded(child: TextField(controller: _aptosPorAndarController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Aptos por Andar (Ex: 4)', border: OutlineInputBorder()))),
                          ],
                        ),
                        
                        const SizedBox(height: 15),
                        const Text("4. Regras de Numeração", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _andarInicialController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Inicia em qual andar? (Ex: 1)', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: TextField(
                                controller: _sufixoInicialController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Sufixo Inicial (Ex: 1)', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _padraoNumeracao,
                                decoration: const InputDecoration(labelText: 'Padrão dos Números', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'por_andar', child: Text("Por Andar (101/201)")),
                                  DropdownMenuItem(value: 'continuo', child: Text("Contínuo (1, 2, 3...)")),
                                ],
                                onChanged: (v) => setStateModal(() => _padraoNumeracao = v!),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
                ElevatedButton.icon(
                  onPressed: _salvarBloco,
                  icon: const Icon(Icons.domain, color: Colors.white),
                  label: Text(_gerarUnidades ? "GERAR PRÉDIO COMPLETO" : "SALVAR BLOCO VAZIO", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
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
            // Cabeçalho da Página
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estrutura do Condomínio',
                  style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                ElevatedButton.icon(
                  onPressed: _abrirModalBloco,
                  icon: const Icon(Icons.add_business, color: Colors.white),
                  label: const Text('ADICIONAR NOVO BLOCO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Lista de Blocos
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
                              const Text('Nenhum bloco cadastrado neste condomínio.'),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 3 / 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _blocos.length,
                          itemBuilder: (context, index) {
                            final bloco = _blocos[index];
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetalheBlocoWeb(
                                        bloco: bloco, 
                                        condominio: widget.condominio
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.apartment, size: 40, color: Colors.blue[800]),
                                    const SizedBox(height: 10),
                                    Text(
                                      bloco['nome'],
                                      style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                    const SizedBox(height: 5),
                                    const Text('Clique para gerenciar', style: TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline)),
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