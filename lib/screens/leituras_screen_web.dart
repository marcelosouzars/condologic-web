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

  Future<void> _carregarCondominios() async {
    setState(() { _isLoading = true; _nivelAtual = 0; });
    try {
      int? userId = _usuarioLogado?['id'];
      String? nivel = _usuarioLogado?['nivel_acesso'] ?? _usuarioLogado?['nivel'];
      final dados = await _apiService.getCondominios(usuarioId: userId, nivel: nivel);
      if (mounted) setState(() { _condominios = dados; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _mostrarErro("Erro ao carregar condomínios: $e");
    }
  }

  Future<void> _carregarBlocos(Map<String, dynamic> condominio) async {
    setState(() { _condominioSelecionado = condominio; _nivelAtual = 1; _isLoading = true; });
    try {
      final dados = await _apiService.getBlocos(condominio['id']);
      if (mounted) setState(() { _blocos = dados; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _mostrarErro("Erro ao carregar blocos: $e");
    }
  }

  Future<void> _carregarUnidades(Map<String, dynamic> bloco) async {
    setState(() { _blocoSelecionado = bloco; _nivelAtual = 2; _isLoading = true; });
    try {
      final dados = await _apiService.getUnidadesPorBloco(bloco['id']);
      dados.sort((a, b) {
        final strA = a['identificacao'].toString();
        final strB = b['identificacao'].toString();
        final numA = int.tryParse(strA.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final numB = int.tryParse(strB.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return numA != numB ? numA.compareTo(numB) : strA.compareTo(strB);
      });
      if (mounted) setState(() { _unidades = dados; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _mostrarErro("Erro ao carregar unidades: $e");
    }
  }

  Future<void> _carregarLeituras(Map<String, dynamic> unidade) async {
    setState(() { _unidadeSelecionada = unidade; _nivelAtual = 3; _isLoading = true; });
    try {
      final dados = await _apiService.getLeituras(_condominioSelecionado!['id'], blocoId: _blocoSelecionado!['id']);
      final leiturasUnidade = dados.where((l) => 
        l['unidade'].toString() == unidade['identificacao'].toString() &&
        l['bloco'].toString() == _blocoSelecionado!['nome'].toString()
      ).toList();
      if (mounted) setState(() { _leituras = leiturasUnidade; _isLoading = false; });
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
        content: url.isNotEmpty ? Image.network(url) : const Text("Imagem indisponível."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('FECHAR'))],
      )
    );
  }

  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(onTap: () => _carregarCondominios(), child: Text("Condomínios", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold))),
          if (_nivelAtual >= 1) ...[const Icon(Icons.chevron_right), InkWell(onTap: () => _carregarBlocos(_condominioSelecionado!), child: Text(_condominioSelecionado!['nome']))],
          if (_nivelAtual >= 2) ...[const Icon(Icons.chevron_right), InkWell(onTap: () => _carregarUnidades(_blocoSelecionado!), child: Text("Bloco ${_blocoSelecionado!['nome']}"))],
          if (_nivelAtual >= 3) ...[const Icon(Icons.chevron_right), Text("Apto ${_unidadeSelecionada!['identificacao']}", style: TextStyle(color: Colors.blue[900]))],
        ],
      ),
    );
  }

  Widget _buildConteudo() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_nivelAtual == 3) {
        Map<String, Map<String, dynamic>> leiturasAgrupadas = {};
        for (var l in _leituras) {
          String dataCurta = (l['data_formatada'] ?? '').toString().split(' ')[0];
          if (!leiturasAgrupadas.containsKey(dataCurta)) {
            leiturasAgrupadas[dataCurta] = {'data': dataCurta, 'agua_fria': '-', 'st_af': '', 'f_af': '', 'agua_quente': '-', 'st_aq': '', 'f_aq': '', 'gas': '-', 'st_g': '', 'f_g': ''};
          }
          String tipo = l['tipo_medidor'].toString().toLowerCase();
          if (tipo.contains('fria')) { leiturasAgrupadas[dataCurta]!['agua_fria'] = l['valor_lido']; leiturasAgrupadas[dataCurta]!['st_af'] = l['status_leitura']; leiturasAgrupadas[dataCurta]!['f_af'] = l['foto_url'] ?? ''; }
          if (tipo.contains('quente')) { leiturasAgrupadas[dataCurta]!['agua_quente'] = l['valor_lido']; leiturasAgrupadas[dataCurta]!['st_aq'] = l['status_leitura']; leiturasAgrupadas[dataCurta]!['f_aq'] = l['foto_url'] ?? ''; }
          if (tipo.contains('gas')) { leiturasAgrupadas[dataCurta]!['gas'] = l['valor_lido']; leiturasAgrupadas[dataCurta]!['st_g'] = l['status_leitura']; leiturasAgrupadas[dataCurta]!['f_g'] = l['foto_url'] ?? ''; }
        }

        DataCell buildCell(dynamic valor, String status, String foto) {
          Color cellColor = Colors.transparent;
          if (status == 'ALERTA_DISCREPANCIA') cellColor = Colors.red[100]!;
          if (status == 'ALERTA_ERRO_IA') cellColor = Colors.orange[100]!;

          return DataCell(
            Container(
              color: cellColor,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(valor.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (foto.isNotEmpty) InkWell(onTap: () => _mostrarFoto(foto, unidadeNome: _unidadeSelecionada!['identificacao']), child: const Text("Ver Foto", style: TextStyle(fontSize: 10, decoration: TextDecoration.underline, color: Colors.blue))),
                ],
              ),
            )
          );
        }

        return Card(
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [DataColumn(label: Text('Data')), DataColumn(label: Text('Água Fria')), DataColumn(label: Text('Água Quente')), DataColumn(label: Text('Gás'))],
              rows: leiturasAgrupadas.values.map((linha) => DataRow(cells: [
                DataCell(Text(linha['data'])),
                buildCell(linha['agua_fria'], linha['st_af'], linha['f_af']),
                buildCell(linha['agua_quente'], linha['st_aq'], linha['f_aq']),
                buildCell(linha['gas'], linha['st_g'], linha['f_g']),
              ])).toList(),
            ),
          ),
        );
    }
    
    // Níveis 0, 1 e 2 (Listas e Grid) permanecem com o seu design original
    List itens = _nivelAtual == 0 ? _condominios : (_nivelAtual == 1 ? _blocos : _unidades);
    if (itens.isEmpty) return const Center(child: Text("Nenhum item encontrado."));

    if (_nivelAtual == 2) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, childAspectRatio: 1.2, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: itens.length,
        itemBuilder: (ctx, i) => InkWell(
          onTap: () => _carregarLeituras(itens[i]),
          child: Card(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.home), Text(itens[i]['identificacao'])]))
        )
      );
    }

    return ListView.builder(
      itemCount: itens.length,
      itemBuilder: (ctx, i) => ListTile(
        title: Text(itens[i]['nome']),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () => _nivelAtual == 0 ? _carregarBlocos(itens[i]) : _carregarUnidades(itens[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AUDITORIA DE FOTOMETRIA', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
        const SizedBox(height: 15),
        _buildBreadcrumbs(),
        const SizedBox(height: 20),
        Expanded(child: _buildConteudo()),
      ],
    );
  }
}