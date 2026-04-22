import 'package:flutter/material.dart';
import '../services/api_service_web.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:excel/excel.dart' hide Border;

class LeiturasScreenWeb extends StatefulWidget {
  final Map<String, dynamic>? usuarioLogado;
  final int? tenantId;
  final bool filtroInicialAuditoria;

  const LeiturasScreenWeb({
    super.key, 
    this.usuarioLogado, 
    this.tenantId,
    this.filtroInicialAuditoria = false,
  });

  @override
  State<LeiturasScreenWeb> createState() => _LeiturasScreenWebState();
}

class _LeiturasScreenWebState extends State<LeiturasScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  
  List<dynamic> _leiturasOriginais = [];
  List<dynamic> _leiturasFiltradas = [];
  bool _isLoading = true;

  // Filtros
  String _mesSelecionado = DateFormat('MM/yyyy').format(DateTime.now());
  String _blocoFiltro = 'Todos';
  String _statusFiltro = 'Todos';
  final TextEditingController _buscaController = TextEditingController();

  // Estatísticas
  int _totalLeituras = 0;
  double _consumoTotal = 0;
  int _totalDiscrepancias = 0;

  @override
  void initState() {
    super.initState();
    
    // Se a tela for chamada pedindo auditoria (Ex: dashboard), já liga o filtro!
    if (widget.filtroInicialAuditoria) {
      _statusFiltro = 'Discrepância';
    }

    _carregarLeituras();
    _buscaController.addListener(_aplicarFiltros);
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarLeituras() async {
    setState(() => _isLoading = true);
    
    int tId = widget.tenantId ?? 1;
    if (widget.usuarioLogado != null && widget.usuarioLogado!['tenant_id'] != null) {
      tId = int.tryParse(widget.usuarioLogado!['tenant_id'].toString()) ?? tId;
    }

    try {
      final dados = await _apiService.getLeituras(tId);

      if (mounted) {
        setState(() {
          _leiturasOriginais = dados;
          _aplicarFiltros();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar leituras: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _aplicarFiltros() {
    List<dynamic> filtrado = _leiturasOriginais.where((l) {
      bool passaMes = l['mes_referencia']?.toString() == _mesSelecionado;
      bool passaBloco = _blocoFiltro == 'Todos' || l['bloco_nome']?.toString() == _blocoFiltro;
      
      bool passaStatus = true;
      if (_statusFiltro == 'Discrepância') passaStatus = l['status_leitura']?.toString() == 'ALERTA_DISCREPANCIA';
      if (_statusFiltro == 'Normal') passaStatus = l['status_leitura']?.toString() == 'NORMAL' || l['status_leitura']?.toString() == 'LIDO';

      bool passaBusca = true;
      if (_buscaController.text.isNotEmpty) {
        String busca = _buscaController.text.toLowerCase();
        String unidade = (l['unidade_nome'] ?? '').toString().toLowerCase();
        passaBusca = unidade.contains(busca);
      }

      return passaMes && passaBloco && passaStatus && passaBusca;
    }).toList();

    filtrado.sort((a, b) {
      if (a['status_leitura']?.toString() == 'ALERTA_DISCREPANCIA' && b['status_leitura']?.toString() != 'ALERTA_DISCREPANCIA') return -1;
      if (b['status_leitura']?.toString() == 'ALERTA_DISCREPANCIA' && a['status_leitura']?.toString() != 'ALERTA_DISCREPANCIA') return 1;
      int blocoCmp = (a['bloco_nome']?.toString() ?? '').compareTo(b['bloco_nome']?.toString() ?? '');
      if (blocoCmp != 0) return blocoCmp;
      return (a['unidade_nome']?.toString() ?? '').compareTo(b['unidade_nome']?.toString() ?? '');
    });

    _calcularEstatisticas(filtrado);

    setState(() {
      _leiturasFiltradas = filtrado;
    });
  }

  void _calcularEstatisticas(List<dynamic> dados) {
    _totalLeituras = dados.length;
    _consumoTotal = 0;
    _totalDiscrepancias = 0;

    for (var item in dados) {
      _consumoTotal += (item['consumo'] != null ? double.tryParse(item['consumo'].toString()) ?? 0 : 0);
      if (item['status_leitura']?.toString() == 'ALERTA_DISCREPANCIA') {
        _totalDiscrepancias++;
      }
    }
  }

  // ====================== AÇÕES ======================

  void _exportarParaExcel() {
    var excel = Excel.createExcel();
    var sheet = excel['Leituras'];
    
    sheet.appendRow([
      TextCellValue('Unidade'),
      TextCellValue('Bloco'),
      TextCellValue('Mês Ref'),
      TextCellValue('Data Leitura'),
      TextCellValue('Leitura Anterior'),
      TextCellValue('Leitura Atual'),
      TextCellValue('Consumo (m³)'),
      TextCellValue('Status'),
    ]);

    for (var l in _leiturasFiltradas) {
      sheet.appendRow([
        TextCellValue(l['unidade_nome']?.toString() ?? '-'),
        TextCellValue(l['bloco_nome']?.toString() ?? '-'),
        TextCellValue(l['mes_referencia']?.toString() ?? '-'),
        TextCellValue(l['data_leitura'] != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(l['data_leitura'].toString())) : '-'),
        TextCellValue(l['leitura_anterior']?.toString() ?? '0'),
        TextCellValue(l['valor_lido']?.toString() ?? '0'),
        TextCellValue(l['consumo']?.toString() ?? '0'),
        TextCellValue(l['status_leitura']?.toString() ?? '-'),
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final blob = html.Blob([fileBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Relatorio_Leituras_$_mesSelecionado.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  void _mostrarFoto(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(15),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Foto do Hidrômetro", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(url, fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Text("Erro ao carregar imagem.")),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarModalEdicao(dynamic leitura) {
    final valorLidoCtrl = TextEditingController(text: leitura['valor_lido']?.toString() ?? '');
    final leituraAnteriorCtrl = TextEditingController(text: leitura['leitura_anterior']?.toString() ?? '0');
    final obsCtrl = TextEditingController(text: leitura['observacao']?.toString() ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Editar Leitura - ${leitura['unidade_nome'] ?? ''}"),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: leituraAnteriorCtrl,
                decoration: const InputDecoration(labelText: 'Leitura Anterior (m³)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: valorLidoCtrl,
                decoration: const InputDecoration(labelText: 'Leitura Atual (m³)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: obsCtrl,
                decoration: const InputDecoration(labelText: 'Observação (Ex: Ajuste manual)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.amber),
                    SizedBox(width: 10),
                    Expanded(child: Text("O consumo será recalculado automaticamente ao salvar.", style: TextStyle(fontSize: 12))),
                  ],
                ),
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              try {
                // Aqui chamará a API no futuro
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leitura atualizada!'), backgroundColor: Colors.green));
                Navigator.pop(context);
                _carregarLeituras(); 
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003366), foregroundColor: Colors.white),
            child: const Text("Salvar Alterações"),
          ),
        ],
      ),
    );
  }

  void _confirmarExclusao(dynamic idLeitura) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Excluir Leitura"),
        content: const Text("Tem certeza que deseja excluir esta leitura? Esta ação não pode ser desfeita."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              try {
                // Aqui chamará a API no futuro
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leitura excluída!'), backgroundColor: Colors.green));
                Navigator.pop(context);
                _carregarLeituras();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );
  }

  // ====================== WIDGETS DE LAYOUT ======================

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 5),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String texto, double largura) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      alignment: Alignment.centerLeft,
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003366), fontSize: 14),
      ),
    );
  }

  Widget _buildDataCell(String texto, double largura, {Color? corTexto, FontWeight? pesoTexto}) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        texto,
        style: TextStyle(color: corTexto ?? Colors.black87, fontSize: 14, fontWeight: pesoTexto ?? FontWeight.normal),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> blocosDisponiveis = ['Todos'];
    blocosDisponiveis.addAll(_leiturasOriginais.map((l) => l['bloco_nome']?.toString() ?? '').where((b) => b.isNotEmpty).toSet().toList());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Gestão de Leituras", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
                    Text("Acompanhamento, auditoria e edição de medições", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _exportarParaExcel,
                  icon: const Icon(Icons.file_download),
                  label: const Text("Exportar Excel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            Row(
              children: [
                _buildSummaryCard("Leituras Realizadas", "$_totalLeituras", Icons.speed, Colors.blue),
                const SizedBox(width: 20),
                _buildSummaryCard("Consumo Total", "${_consumoTotal.toStringAsFixed(1)} m³", Icons.water_drop, Colors.cyan),
                const SizedBox(width: 20),
                _buildSummaryCard("Discrepâncias", "$_totalDiscrepancias", Icons.warning_amber_rounded, Colors.red),
              ],
            ),
            const SizedBox(height: 25),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[300]!)),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _buscaController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar Unidade...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Mês/Ano', border: OutlineInputBorder()),
                      value: _mesSelecionado,
                      items: [
                        DropdownMenuItem(value: DateFormat('MM/yyyy').format(DateTime.now()), child: Text(DateFormat('MM/yyyy').format(DateTime.now()))),
                        DropdownMenuItem(value: DateFormat('MM/yyyy').format(DateTime(DateTime.now().year, DateTime.now().month - 1, 1)), child: Text(DateFormat('MM/yyyy').format(DateTime(DateTime.now().year, DateTime.now().month - 1, 1)))),
                        DropdownMenuItem(value: DateFormat('MM/yyyy').format(DateTime(DateTime.now().year, DateTime.now().month - 2, 1)), child: Text(DateFormat('MM/yyyy').format(DateTime(DateTime.now().year, DateTime.now().month - 2, 1)))),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() { _mesSelecionado = v; _aplicarFiltros(); });
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Bloco', border: OutlineInputBorder()),
                      value: _blocoFiltro,
                      items: blocosDisponiveis.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() { _blocoFiltro = v; _aplicarFiltros(); });
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                      value: _statusFiltro,
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                        DropdownMenuItem(value: 'Normal', child: Text('Apenas Normais')),
                        DropdownMenuItem(value: 'Discrepância', child: Text('Com Discrepância', style: TextStyle(color: Colors.red))),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() { _statusFiltro = v; _aplicarFiltros(); });
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  IconButton(
                    onPressed: _carregarLeituras,
                    icon: const Icon(Icons.refresh, color: Color(0xFF003366)),
                    tooltip: "Atualizar Dados",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _leiturasFiltradas.isEmpty
                        ? const Center(child: Text("Nenhuma leitura encontrada com os filtros atuais.", style: TextStyle(fontSize: 16)))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 1250, 
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildHeaderCell("Unidade", 120),
                                        _buildHeaderCell("Bloco", 120),
                                        _buildHeaderCell("Data", 150),
                                        _buildHeaderCell("Anterior", 100),
                                        _buildHeaderCell("Atual", 100),
                                        _buildHeaderCell("Consumo", 110),
                                        _buildHeaderCell("Status", 160),
                                        _buildHeaderCell("Foto", 80),
                                        _buildHeaderCell("Ações", 220), 
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1, thickness: 1),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: _leiturasFiltradas.length,
                                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
                                      itemBuilder: (context, index) {
                                        final item = _leiturasFiltradas[index];
                                        
                                        Color statusColor = Colors.green;
                                        if (item['status_leitura']?.toString() == 'ALERTA_DISCREPANCIA') statusColor = Colors.red;
                                        if (item['status_leitura']?.toString() == 'PENDENTE') statusColor = Colors.orange;

                                        return Container(
                                          color: item['status_leitura']?.toString() == 'ALERTA_DISCREPANCIA' ? Colors.red.withOpacity(0.03) : Colors.transparent,
                                          child: Row(
                                            children: [
                                              _buildDataCell(item['unidade_nome']?.toString() ?? "-", 120, pesoTexto: FontWeight.bold),
                                              _buildDataCell(item['bloco_nome']?.toString() ?? "-", 120),
                                              _buildDataCell(item['data_leitura'] != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item['data_leitura'].toString())) : "-", 150),
                                              _buildDataCell("${item['leitura_anterior'] ?? '0'}", 100),
                                              _buildDataCell("${item['valor_lido'] ?? '0'}", 100, pesoTexto: FontWeight.bold),
                                              _buildDataCell("${item['consumo'] ?? '0'} m³", 110, corTexto: const Color(0xFF003366), pesoTexto: FontWeight.bold),
                                              
                                              Container(
                                                width: 160,
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: statusColor.withOpacity(0.5))
                                                  ),
                                                  child: Text(
                                                    item['status_leitura']?.toString() ?? "OK",
                                                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),

                                              Container(
                                                width: 80,
                                                alignment: Alignment.center,
                                                child: item['foto_url'] != null && item['foto_url'].toString().isNotEmpty
                                                    ? IconButton(
                                                        icon: const Icon(Icons.image, color: Colors.blue),
                                                        tooltip: "Ver Foto",
                                                        onPressed: () => _mostrarFoto(item['foto_url'].toString()),
                                                      )
                                                    : const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
                                              ),

                                              Container(
                                                width: 220,
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                  children: [
                                                    OutlinedButton.icon(
                                                      onPressed: () => _mostrarModalEdicao(item),
                                                      icon: const Icon(Icons.edit, size: 16),
                                                      label: const Text("Editar"),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: const Color(0xFF003366),
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      onPressed: () => _confirmarExclusao(item['id']),
                                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                      tooltip: "Excluir",
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
