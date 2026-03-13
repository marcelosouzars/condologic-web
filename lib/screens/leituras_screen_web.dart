import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service_web.dart';

class LeiturasScreenWeb extends StatefulWidget {
  final int tenantId;
  const LeiturasScreenWeb({super.key, required this.tenantId});

  @override
  State<LeiturasScreenWeb> createState() => _LeiturasScreenWebState();
}

class _LeiturasScreenWebState extends State<LeiturasScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  
  bool _isLoading = true;
  Map<String, dynamic>? _usuarioLogado;

  // --- CONTROLE DE NAVEGAÇÃO "BONECAS RUSSAS" (DRILL-DOWN) ---
  // Níveis: 0 = Condomínios, 1 = Blocos, 2 = Unidades, 3 = Leituras
  int _nivelAtual = 0;

  List<dynamic> _condominios = [];
  List<dynamic> _blocos = [];
  List<dynamic> _unidades = [];
  List<dynamic> _leituras = [];

  Map<String, dynamic>? _condominioSelecionado;
  Map<String, dynamic>? _blocoSelecionado;
  Map<String, dynamic>? _unidadeSelecionada;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('usuario_dados');
    if (userString != null) {
      _usuarioLogado = jsonDecode(userString);
    }
    await _carregarCondominios();
  }

  // --- NÍVEL 0: CARREGAR CONDOMÍNIOS ---
  Future<void> _carregarCondominios() async {
    setState(() { _isLoading = true; _nivelAtual = 0; });
    try {
      int? userId = _usuarioLogado?['id'];
      String? nivel = _usuarioLogado?['nivel_acesso'] ?? _usuarioLogado?['nivel'];
      final dados = await _apiService.getCondominios(usuarioId: userId, nivel: nivel);
      
      if (mounted) {
        setState(() {
          _condominios = dados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _mostrarErro("Erro ao carregar condomínios: $e");
    }
  }

  // --- NÍVEL 1: CARREGAR BLOCOS DO CONDOMÍNIO ---
  Future<void> _carregarBlocos(Map<String, dynamic> condominio) async {
    setState(() {
      _condominioSelecionado = condominio;
      _nivelAtual = 1;
      _isLoading = true;
    });
    try {
      final dados = await _apiService.getBlocos(condominio['id']);
      if (mounted) {
        setState(() {
          _blocos = dados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _mostrarErro("Erro ao carregar blocos: $e");
    }
  }

  // --- NÍVEL 2: CARREGAR UNIDADES DO BLOCO COM ORDENAÇÃO INTELIGENTE ---
  Future<void> _carregarUnidades(Map<String, dynamic> bloco) async {
    setState(() {
      _blocoSelecionado = bloco;
      _nivelAtual = 2;
      _isLoading = true;
    });
    try {
      final dados = await _apiService.getUnidadesPorBloco(bloco['id']);
      
      // ITEM 3 RESOLVIDO: Ordenação matemática crescente dos apartamentos
      dados.sort((a, b) {
        final strA = a['identificacao'].toString();
        final strB = b['identificacao'].toString();
        final numA = int.tryParse(strA.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final numB = int.tryParse(strB.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (numA != numB) return numA.compareTo(numB);
        return strA.compareTo(strB); // Fallback para letras (ex: 101A, 101B)
      });

      if (mounted) {
        setState(() {
          _unidades = dados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _mostrarErro("Erro ao carregar unidades: $e");
    }
  }

  // --- NÍVEL 3: CARREGAR LEITURAS DA UNIDADE ---
  Future<void> _carregarLeituras(Map<String, dynamic> unidade) async {
    setState(() {
      _unidadeSelecionada = unidade;
      _nivelAtual = 3;
      _isLoading = true;
    });
    try {
      final dados = await _apiService.getLeituras(_condominioSelecionado!['id'], blocoId: _blocoSelecionado!['id']);
      
      final leiturasUnidade = dados.where((l) => 
        l['unidade'].toString() == unidade['identificacao'].toString() &&
        l['bloco'].toString() == _blocoSelecionado!['nome'].toString()
      ).toList();

      if (mounted) {
        setState(() {
          _leituras = leiturasUnidade;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _mostrarErro("Erro ao carregar as leituras: $e");
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _mostrarFoto(String url, {required String unidadeNome}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Foto do Medidor - Unidade $unidadeNome'),
        content: url.isNotEmpty 
            ? Image.network(url, errorBuilder: (c, e, s) => const Text("Erro ao carregar a imagem da nuvem."))
            : const Text("Imagem indisponível no banco de dados."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('FECHAR'))
        ],
      )
    );
  }

  // --- COMPONENTE BREADCRUMB (Navegação Superior) ---
  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2))
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: () => _carregarCondominios(),
            child: Text("Condomínios", style: TextStyle(color: _nivelAtual == 0 ? Colors.blue[900] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (_nivelAtual >= 1 && _condominioSelecionado != null) ...[
            const Icon(Icons.chevron_right, color: Colors.grey),
            InkWell(
              onTap: () => _carregarBlocos(_condominioSelecionado!),
              child: Text(_condominioSelecionado!['nome'], style: TextStyle(color: _nivelAtual == 1 ? Colors.blue[900] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
          if (_nivelAtual >= 2 && _blocoSelecionado != null) ...[
            const Icon(Icons.chevron_right, color: Colors.grey),
            InkWell(
              onTap: () => _carregarUnidades(_blocoSelecionado!),
              child: Text("Bloco ${_blocoSelecionado!['nome']}", style: TextStyle(color: _nivelAtual == 2 ? Colors.blue[900] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
          if (_nivelAtual >= 3 && _unidadeSelecionada != null) ...[
            const Icon(Icons.chevron_right, color: Colors.grey),
            Text("Apto ${_unidadeSelecionada!['identificacao']}", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ],
      ),
    );
  }

  // --- GERADOR DA LISTA DINÂMICA (Baseada no Nível Atual) ---
  Widget _buildConteudo() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    switch (_nivelAtual) {
      
      // ========================================== NÍVEL 0: CONDOMÍNIOS
      case 0: 
        if (_condominios.isEmpty) return const Center(child: Text("Nenhum condomínio encontrado.", style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          itemCount: _condominios.length,
          itemBuilder: (ctx, i) {
            final c = _condominios[i];
            return Card(
              elevation: 2, margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: Colors.blue[100], child: Icon(Icons.apartment, color: Colors.blue[900])),
                title: Text(c['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: const Text("Clique para acessar as torres/blocos"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.blue),
                onTap: () => _carregarBlocos(c),
              ),
            );
          }
        );

      // ========================================== NÍVEL 1: BLOCOS
      case 1: 
        if (_blocos.isEmpty) return const Center(child: Text("Nenhum bloco ou torre cadastrado para este condomínio.", style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          itemCount: _blocos.length,
          itemBuilder: (ctx, i) {
            final b = _blocos[i];
            return Card(
              elevation: 2, margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: Colors.orange[100], child: Icon(Icons.domain, color: Colors.orange[900])),
                title: Text(b['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: const Text("Clique para abrir as unidades"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.orange),
                onTap: () => _carregarUnidades(b),
              ),
            );
          }
        );

      // ========================================== NÍVEL 2: UNIDADES (Em Grid)
      case 2: 
        if (_unidades.isEmpty) return const Center(child: Text("Nenhuma unidade cadastrada neste bloco.", style: TextStyle(color: Colors.grey)));
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160, childAspectRatio: 1.2, crossAxisSpacing: 12, mainAxisSpacing: 12
          ),
          itemCount: _unidades.length,
          itemBuilder: (ctx, i) {
            final u = _unidades[i];
            return InkWell(
              onTap: () => _carregarLeituras(u),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_outlined, color: Colors.blue[800], size: 35),
                    const SizedBox(height: 10),
                    Text(u['identificacao'], style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    const Text("Ver Relógios", style: TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline, fontWeight: FontWeight.bold))
                  ]
                )
              )
            );
          }
        );

      // ========================================== NÍVEL 3: LEITURAS (TABELA / PLANILHA)
      case 3: 
        if (_leituras.isEmpty) return const Center(child: Text("Nenhuma leitura finalizada encontrada para esta unidade.", style: TextStyle(color: Colors.grey)));

        // ITEM 4 RESOLVIDO: Agrupamento em formato de Planilha (Data nas Linhas, Medidores nas Colunas)
        Map<String, Map<String, dynamic>> leiturasAgrupadas = {};
        
        for (var l in _leituras) {
          String dataHora = l['data_formatada'] ?? 'Sem Data';
          String dataCurta = dataHora.length >= 10 ? dataHora.substring(0, 10) : dataHora;
          
          if (!leiturasAgrupadas.containsKey(dataCurta)) {
            leiturasAgrupadas[dataCurta] = {
              'data': dataCurta,
              'agua_fria': '-', 'foto_agua_fria': '',
              'agua_quente': '-', 'foto_agua_quente': '',
              'gas': '-', 'foto_gas': ''
            };
          }
          
          String tipo = l['tipo_medidor'].toString().toLowerCase();
          String valor = "${l['valor_lido']}"; 
          String foto = l['foto_url'] ?? '';
          
          if (tipo == 'agua_fria') {
            leiturasAgrupadas[dataCurta]!['agua_fria'] = valor;
            leiturasAgrupadas[dataCurta]!['foto_agua_fria'] = foto;
          } else if (tipo == 'agua_quente') {
            leiturasAgrupadas[dataCurta]!['agua_quente'] = valor;
            leiturasAgrupadas[dataCurta]!['foto_agua_quente'] = foto;
          } else if (tipo == 'gas' || tipo == 'gás') {
            leiturasAgrupadas[dataCurta]!['gas'] = valor;
            leiturasAgrupadas[dataCurta]!['foto_gas'] = foto;
          }
        }
        
        List<Map<String, dynamic>> linhasTabela = leiturasAgrupadas.values.toList();
        
        // Função auxiliar para desenhar a célula com número e botão da foto
        DataCell buildCell(String valor, String fotoUrl) {
          if (valor == '-') return const DataCell(Center(child: Text('-', style: TextStyle(color: Colors.grey))));
          return DataCell(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (fotoUrl.isNotEmpty)
                    InkWell(
                      onTap: () => _mostrarFoto(fotoUrl, unidadeNome: _unidadeSelecionada!['identificacao']),
                      child: const Text("Ver Foto", style: TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline)),
                    )
                ],
              ),
            )
          );
        }

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                dataRowMaxHeight: 75,
                dataRowMinHeight: 60,
                columns: const [
                  DataColumn(label: Text('Data da Medição', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Água Fria', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                  DataColumn(label: Text('Água Quente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                  DataColumn(label: Text('Gás', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
                ],
                rows: linhasTabela.map((linha) {
                  return DataRow(cells: [
                    DataCell(Text(linha['data'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    buildCell(linha['agua_fria'], linha['foto_agua_fria']),
                    buildCell(linha['agua_quente'], linha['foto_agua_quente']),
                    buildCell(linha['gas'], linha['foto_gas']),
                  ]);
                }).toList(),
              ),
            ),
          ),
        );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AUDITORIA DE FOTOMETRIA', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
        const SizedBox(height: 5),
        const Text('Navegue pelas pastas abaixo para consultar as fotos e os resultados processados pela Inteligência Artificial.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 15),
        
        // BREADCRUMB
        _buildBreadcrumbs(),
        
        const SizedBox(height: 20),
        
        // CONTEÚDO (Lista de itens do nível atual ou Tabela)
        Expanded(child: _buildConteudo()),
      ],
    );
  }
}