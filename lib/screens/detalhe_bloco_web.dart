// ==========================================>>> detalhe_bloco_web.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
  Map<String, dynamic>? _usuarioLogado; // <<< Adicionado para controle de acesso

  // --- CONTROLADOR DA CRIAÇÃO MANUAL AVULSA ---
  final _identificacaoManualController = TextEditingController();
  final _andarManualController = TextEditingController();

  // --- CONTROLADOR DA EXCLUSÃO AVULSA ---
  final _unidadeExclusaoController = TextEditingController();

  bool _temAguaFria = true; 
  bool _temGas = true;
  bool _temAguaQuente = true;
  int _digitosVermelhos = 3; 

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
    _carregarUnidades();
  }

  // >>> FUNÇÃO NOVA: Carregar usuário para verificar se é Master
  Future<void> _carregarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('usuario_dados');
    if (userString != null && mounted) {
      setState(() {
        _usuarioLogado = jsonDecode(userString);
      });
    }
  }

  Future<void> _carregarUnidades() async {
    setState(() => _isLoading = true);
    try {
      final unidadesRaw = await _apiService.getUnidadesPorBloco(widget.bloco['id']);
      List<dynamic> unidadesOrdenadas = List.from(unidadesRaw);
      
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

  void _mostrarErro(String mensagem) {
    final msgLimpa = mensagem.replaceFirst('Exception: ', '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('Atenção', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(msgLimpa, style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK, ENTENDI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // 1. FLUXO DE CRIAÇÃO MANUAL
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
        'criar_medidores': medidores,
        'digitos_vermelhos': _digitosVermelhos 
      });

      if (mounted) {
        Navigator.pop(context);
        _identificacaoManualController.clear();
        _carregarUnidades();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unidade avulsa criada!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        _mostrarErro(e.toString());
      }
    }
  }

  void _abrirModalCriacao() {
    _identificacaoManualController.clear();
    _andarManualController.clear();
    _temAguaFria = true; 
    _temGas = true; 
    _temAguaQuente = true;
    _digitosVermelhos = 3;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  Icon(Icons.add_home, color: Colors.blue[900]),
                  const SizedBox(width: 10),
                  const Text('Adicionar Unidade Avulsa'),
                ],
              ),
              content: SizedBox(
                width: 400, 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Utilize para adicionar unidades fora do padrão gerado (Ex: Casa de Máquinas, Cobertura, Sala do Síndico).", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    TextField(controller: _identificacaoManualController, decoration: const InputDecoration(labelText: 'Identificação (Ex: COB-01)', border: OutlineInputBorder())),
                    const SizedBox(height: 15),
                    TextField(controller: _andarManualController, decoration: const InputDecoration(labelText: 'Andar (Ex: Cobertura)', border: OutlineInputBorder())),
                    
                    const SizedBox(height: 15),
                    DropdownButtonFormField<int>(
                      value: _digitosVermelhos,
                      decoration: const InputDecoration(
                        labelText: 'Formato do Medidor (Dígitos Vermelhos)', 
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.speed, color: Colors.red)
                      ),
                      items: const [
                        DropdownMenuItem(value: 3, child: Text("3 Dígitos Vermelhos (Lê até o litro)")),
                        DropdownMenuItem(value: 2, child: Text("2 Dígitos Vermelhos (Lê a cada 10 litros)")),
                        DropdownMenuItem(value: 0, child: Text("Sem vermelhos (Só pretos)")),
                      ],
                      onChanged: (v) => setStateModal(() => _digitosVermelhos = v!),
                    ),

                    const SizedBox(height: 15),
                    const Text("Medidores desta unidade:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Expanded(child: CheckboxListTile(title: const Text("Água Fria", style: TextStyle(fontSize: 12)), value: _temAguaFria, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setStateModal(() => _temAguaFria = v!))),
                        Expanded(child: CheckboxListTile(title: const Text("Gás", style: TextStyle(fontSize: 12)), value: _temGas, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setStateModal(() => _temGas = v!))),
                        Expanded(child: CheckboxListTile(title: const Text("Quente", style: TextStyle(fontSize: 12)), value: _temAguaQuente, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setStateModal(() => _temAguaQuente = v!))),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  label: const Text("CANCELAR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  ),
                ),
                const SizedBox(width: 5),
                ElevatedButton.icon(
                  onPressed: _salvarUnidadeManual, 
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("ADICIONAR UNIDADE", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)),
                )
              ],
            );
          },
        );
      },
    );
  }

  // ======================================================
  // 2. FLUXO DE EXCLUSÃO MANUAL (DUPLA CONFIRMAÇÃO)
  // ======================================================
  void _abrirModalPedirUnidadeExclusao() {
    _unidadeExclusaoController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.domain_disabled, color: Colors.red[800], size: 30),
            const SizedBox(width: 10),
            Text('Excluir Unidade', style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Qual a identificação/número da unidade que deseja excluir?"),
            const SizedBox(height: 15),
            TextField(
              controller: _unidadeExclusaoController,
              decoration: const InputDecoration(labelText: 'Ex: 102, COB-01', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close, color: Colors.grey),
            label: const Text("CANCELAR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey, width: 1.5), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (_unidadeExclusaoController.text.isNotEmpty) {
                Navigator.pop(ctx);
                _abrirModalConfirmacaoExclusao(_unidadeExclusaoController.text);
              }
            },
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            label: const Text("PROSSEGUIR", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)),
          )
        ],
      )
    );
  }

  void _abrirModalConfirmacaoExclusao(String identificacao) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('Confirmação de Exclusão', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("CONFIRMA A EXCLUSÃO DA UNIDADE '$identificacao' E SEUS MEDIDORES?", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close, color: Colors.grey),
            label: const Text("NÃO, CANCELAR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey, width: 1.5), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx); // Fecha modal confirmação
              showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
              try {
                await _apiService.excluirUnidade(widget.bloco['id'], identificacao);
                if (mounted) {
                  Navigator.pop(context); // Fecha loading
                  _carregarUnidades();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unidade excluída com sucesso!'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Fecha loading
                  _mostrarErro(e.toString());
                }
              }
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text("SIM, EXCLUIR", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)),
          )
        ],
      )
    );
  }

  // ======================================================
  // 3. FLUXO DE EXCLUSÃO DO BLOCO INTEIRO (NOVO!)
  // ======================================================
  void _abrirModalConfirmacaoExclusaoBloco() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.dangerous, color: Colors.red[900], size: 35),
            const SizedBox(width: 10),
            Text('ATENÇÃO MÁXIMA', style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "VOCÊ ESTÁ PRESTES A APAGAR O BLOCO INTEIRO:\n\n"
          "► Bloco: ${widget.bloco['nome']}\n"
          "► Unidades vinculadas: ${_unidades.length}\n\n"
          "Esta ação APAGARÁ DEFINITIVAMENTE todas as unidades, medidores e o histórico de leituras. NÃO pode ser desfeita.", 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close, color: Colors.grey),
            label: const Text("CANCELAR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey, width: 1.5), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx); // Fecha modal
              showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
              try {
                String nivelAcesso = _usuarioLogado?['nivel_acesso'] ?? _usuarioLogado?['nivel'] ?? '';
                
                await _apiService.excluirBloco(widget.bloco['id'], nivelAcesso);
                
                if (mounted) {
                  Navigator.pop(context); // Fecha loading
                  Navigator.pop(context, true); // VOLTA PARA A TELA DE CONDOMÍNIO (Fechando o bloco)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bloco inteiro excluído com sucesso!'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Fecha loading
                  _mostrarErro(e.toString());
                }
              }
            },
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            label: const Text("SIM, EXCLUIR BLOCO INTEIRO", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900], padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // >>> VERIFICA SE O USUÁRIO É MASTER PARA EXIBIR O NOVO BOTÃO <<<
    String nivelUsuario = _usuarioLogado?['nivel_acesso']?.toString().toLowerCase() ?? _usuarioLogado?['nivel']?.toString().toLowerCase() ?? '';
    bool isMaster = (nivelUsuario == 'master');

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
            // >>> AQUI ESTÃO OS CARDS SUPERIORES <<<
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
                          Icon(Icons.add_home_work, color: Colors.blue[800], size: 40),
                          const SizedBox(width: 15),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("ADICIONAR UNIDADE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("Criar unidade avulsa", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: InkWell(
                    onTap: _abrirModalPedirUnidadeExclusao,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.5), width: 2)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.domain_disabled, color: Colors.red[800], size: 40),
                          const SizedBox(width: 15),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("EXCLUIR UNIDADE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                              Text("Remover unidade avulsa", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                // >>> NOVO CARD: EXCLUIR BLOCO (APENAS MASTER) <<<
                if (isMaster) ...[
                  const SizedBox(width: 15),
                  Expanded(
                    child: InkWell(
                      onTap: _abrirModalConfirmacaoExclusaoBloco,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade900, width: 2)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_sweep, color: Colors.red[900], size: 40),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("EXCLUIR BLOCO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red[900])),
                                Text("Apagar torre inteira", style: TextStyle(color: Colors.red[700], fontSize: 12)),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ]
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _unidades.isEmpty
                      ? const Center(child: Text("Nenhuma unidade encontrada neste bloco.", style: TextStyle(fontSize: 16)))
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