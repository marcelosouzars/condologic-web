import 'dart:convert';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:excel/excel.dart'; 
import 'package:intl/intl.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import '../services/api_service_web.dart';

class RelatoriosScreenWeb extends StatefulWidget {
  const RelatoriosScreenWeb({super.key});

  @override
  State<RelatoriosScreenWeb> createState() => _RelatoriosScreenWebState();
}

class _RelatoriosScreenWebState extends State<RelatoriosScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  
  List<dynamic> _leiturasBrutas = [];
  List<dynamic> _leiturasFiltradas = [];
  
  List<dynamic> _condominios = [];
  List<dynamic> _blocos = [];
  List<String> _andares = [];
  List<dynamic> _unidades = [];

  int? _selectedTenantId;
  Map<String, dynamic>? _selectedBloco;
  String? _selectedAndar;
  Map<String, dynamic>? _selectedUnidade;
  
  DateTimeRange _dataSelecionada = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  bool _isLoading = false;
  bool _jaBuscou = false;

  @override
  void initState() {
    super.initState();
    _carregarCondominios();
  }

  String _formatarMedicao(dynamic valor) {
    if (valor == null) return '0,000';
    double v = double.tryParse(valor.toString()) ?? 0.0;
    return v.toStringAsFixed(3).replaceAll('.', ',');
  }

  String _formatarMoeda(dynamic valor) {
    if (valor == null) return '0,00';
    double v = double.tryParse(valor.toString()) ?? 0.0;
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  Widget _buildHeaderCell(String text, {int flex = 1, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? Colors.black87, fontSize: 13)),
    );
  }

  Widget _buildDataCell(Widget content, {int flex = 1}) {
    return Expanded(flex: flex, child: content);
  }

  Future<void> _carregarCondominios() async {
    try {
      final dados = await _apiService.getCondominios();
      if (mounted) {
        setState(() {
          _condominios = dados;
          if (_condominios.isNotEmpty) {
            _selectedTenantId = _condominios[0]['id'];
            _carregarBlocos(_selectedTenantId!);
          }
        });
      }
    } catch (e) {
      print("Erro ao carregar condomínios: $e");
    }
  }

  Future<void> _carregarBlocos(int tenantId) async {
    try {
      final dados = await _apiService.getBlocos(tenantId);
      if (mounted) {
        setState(() {
          _blocos = dados;
          _selectedBloco = null;
          _selectedAndar = null;
          _selectedUnidade = null;
          _andares = [];
          _unidades = [];
        });
      }
    } catch (e) {
      print("Erro ao carregar blocos: $e");
    }
  }

  Future<void> _carregarUnidadesEAndares(int blocoId) async {
    try {
      final dados = await _apiService.getUnidadesPorBloco(blocoId);
      if (mounted) {
        setState(() {
          _unidades = dados;
          final andaresUnicos = _unidades.map((u) => u['andar']?.toString() ?? 'Térreo').toSet().toList();
          andaresUnicos.sort((a, b) {
            if (a.toLowerCase() == 'térreo') return -1;
            if (b.toLowerCase() == 'térreo') return 1;
            final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
            final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
            if (numA != null && numB != null) return numA.compareTo(numB);
            return a.compareTo(b); 
          });
          _andares = andaresUnicos;
          _selectedAndar = null;
          _selectedUnidade = null;
        });
      }
    } catch (e) {
      print("Erro ao carregar unidades: $e");
    }
  }

  Future<void> _buscarRelatorio() async {
    if (_selectedTenantId == null) return;
    setState(() { _isLoading = true; _jaBuscou = true; _leiturasBrutas = []; _leiturasFiltradas = []; });
    try {
      final dtInicioStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.start);
      final dtFimStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.end);
      List<dynamic> dados = await _apiService.getLeituras(_selectedTenantId!, dtInicio: dtInicioStr, dtFim: dtFimStr, blocoId: _selectedBloco?['id']);
      if (dados.isEmpty) dados = await _apiService.getLeituras(_selectedTenantId!, blocoId: _selectedBloco?['id']);
      
      if (mounted) setState(() { _leiturasBrutas = dados; _aplicarFiltrosLocais(); _isLoading = false; });
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar dados: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _aplicarFiltrosLocais() {
    setState(() {
      _leiturasFiltradas = _leiturasBrutas.where((leitura) {
        bool passaData = true;
        try {
          String dataStr = (leitura['data_formatada'] ?? leitura['data_leitura'] ?? '').toString();
          if (dataStr.isNotEmpty && dataStr != '-') {
            DateTime? dtLeitura;
            if (dataStr.contains('/')) {
              final p = dataStr.split(' ')[0].split('/');
              if (p.length == 3) dtLeitura = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
            } else if (dataStr.contains('-')) {
              dtLeitura = DateTime.tryParse(dataStr);
            }
            if (dtLeitura != null) {
              DateTime start = DateTime(_dataSelecionada.start.year, _dataSelecionada.start.month, _dataSelecionada.start.day);
              DateTime end = DateTime(_dataSelecionada.end.year, _dataSelecionada.end.month, _dataSelecionada.end.day, 23, 59, 59);
              passaData = dtLeitura.isAfter(start.subtract(const Duration(days: 1))) && dtLeitura.isBefore(end);
            }
          }
        } catch (_) {} 

        bool passaBloco = true;
        if (_selectedBloco != null) {
          String blocoLeitura = (leitura['bloco'] ?? leitura['bloco_nome'] ?? '').toString().trim().toLowerCase();
          passaBloco = blocoLeitura == _selectedBloco!['nome'].toString().trim().toLowerCase();
        }
        
        bool passaAndar = true;
        String unidLeitura = (leitura['unidade'] ?? leitura['identificacao'] ?? '').toString().trim().toLowerCase();
        if (_selectedAndar != null && _selectedUnidade == null) {
          List<String> unidsDoAndar = _unidades.where((u) => (u['andar']?.toString().trim().toLowerCase() ?? 'térreo') == _selectedAndar!.trim().toLowerCase()).map((u) => (u['identificacao'] ?? '').toString().trim().toLowerCase()).toList();
          passaAndar = unidsDoAndar.contains(unidLeitura);
        }

        bool passaUnidade = true;
        if (_selectedUnidade != null) passaUnidade = unidLeitura == _selectedUnidade!['identificacao'].toString().trim().toLowerCase();

        return passaData && passaBloco && passaAndar && passaUnidade;
      }).toList();
    });
  }

  Future<void> _selecionarPeriodo() async {
    DateTime inicioTemp = _dataSelecionada.start;
    DateTime fimTemp = _dataSelecionada.end;

    await showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Icon(Icons.date_range, color: Colors.blue[900]),
                  const SizedBox(width: 10),
                  Text("Selecionar Período", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Defina a data inicial e final para o filtro:", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(context: context, initialDate: inicioTemp, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                            if (picked != null) setStateModal(() => inicioTemp = picked);
                          },
                          child: InputDecorator(decoration: const InputDecoration(labelText: "Data Inicial", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today, size: 20)), child: Text(DateFormat('dd/MM/yyyy').format(inicioTemp), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Icon(Icons.arrow_forward, color: Colors.grey),
                      const SizedBox(width: 15),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(context: context, initialDate: fimTemp, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                            if (picked != null) setStateModal(() => fimTemp = picked);
                          },
                          child: InputDecorator(decoration: const InputDecoration(labelText: "Data Final", border: OutlineInputBorder(), prefixIcon: Icon(Icons.event, size: 20)), child: Text(DateFormat('dd/MM/yyyy').format(fimTemp), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ],
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.red))),
                ElevatedButton(
                  onPressed: () {
                    if (fimTemp.isBefore(inicioTemp)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A Data Final não pode ser anterior à Data Inicial."), backgroundColor: Colors.red));
                      return;
                    }
                    setState(() { _dataSelecionada = DateTimeRange(start: inicioTemp, end: fimTemp); _jaBuscou = false; });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                  child: const Text("CONFIRMAR DATAS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _exportarExcel() {
    if (_leiturasFiltradas.isEmpty) return;

    final nomeCond = _condominios.firstWhere((c) => c['id'] == _selectedTenantId, orElse: () => {'nome': 'Condomínio'})['nome'];
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Relatório Fotometria'];
    excel.setDefaultSheet('Relatório Fotometria');

    sheetObject.appendRow([
      TextCellValue("Condomínio"), TextCellValue("Data / Hora da Leitura"), TextCellValue("Bloco"), 
      TextCellValue("Unidade"), TextCellValue("Tipo Medidor"), TextCellValue("Leitura Anterior (Mês Passado)"), 
      TextCellValue("Leitura Atual (Mês Atual)"), TextCellValue("Consumo Registrado (m³)"), TextCellValue("Valor Faturado (R\$)")
    ]);

    for (var row in _leiturasFiltradas) {
      sheetObject.appendRow([
        TextCellValue(nomeCond.toString()), TextCellValue(row['data_formatada']?.toString() ?? '-'),
        TextCellValue(row['bloco']?.toString() ?? '-'), TextCellValue(row['unidade']?.toString() ?? '-'),
        TextCellValue(row['tipo_medidor']?.toString().toUpperCase() ?? '-'), TextCellValue(_formatarMedicao(row['leitura_anterior'])),
        TextCellValue(_formatarMedicao(row['valor_lido'])), TextCellValue(_formatarMedicao(row['consumo'])), TextCellValue(_formatarMoeda(row['valor_total_faturado'])),
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final blob = html.Blob([Uint8List.fromList(fileBytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)..setAttribute("download", "Consumo_CondoLogic_${DateFormat('ddMMyyyy').format(DateTime.now())}.xlsx")..click();
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Planilha baixada!'), backgroundColor: Colors.green[700]));
    }
  }

  // ==============================================================
  // O NOVO GERADOR DE PDF A4 RETRATO COM SOMA TOTAL E CABEÇALHOS REPETIDOS
  // ==============================================================
  Future<void> _imprimirPDF() async {
    if (_leiturasFiltradas.isEmpty) return;
    final doc = pw.Document();
    final nomeCond = _condominios.firstWhere((c) => c['id'] == _selectedTenantId, orElse: () => {'nome': 'Condomínio'})['nome'];
    final dataGeracao = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final periodoStr = "${DateFormat('dd/MM/yyyy').format(_dataSelecionada.start)} a ${DateFormat('dd/MM/yyyy').format(_dataSelecionada.end)}";

    // Cálculo do Total Faturado
    double totalFaturado = 0.0;
    for (var l in _leiturasFiltradas) {
      totalFaturado += double.tryParse(l['valor_total_faturado']?.toString() ?? '0') ?? 0.0;
    }

    pw.Widget buildPdfHeader(String text) {
      return pw.Container(
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
      );
    }

    pw.Widget buildPdfCell(String text, {pw.Alignment alignment = pw.Alignment.centerLeft, bool isBold = false, PdfColor textColor = PdfColors.black}) {
      return pw.Container(
        alignment: alignment,
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 7, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: textColor)),
      );
    }

    pw.Widget buildPdfChip(String tipo) {
      PdfColor corFundo = PdfColors.blue600;
      String texto = tipo.toUpperCase();
      if (tipo.toLowerCase().contains('quente')) corFundo = PdfColors.red600;
      else if (tipo.toLowerCase().contains('gas') || tipo.toLowerCase().contains('gás')) corFundo = PdfColors.orange600;

      return pw.Container(
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.all(2),
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(color: corFundo, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3))),
          child: pw.Text(texto, style: pw.TextStyle(color: PdfColors.white, fontSize: 6, fontWeight: pw.FontWeight.bold))
        )
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4, // Agora em Folha A4 Retrato Padrão
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0, 
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                children: [
                  pw.Text("Relatório de Consumo e Faturamento", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text(nomeCond, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ]
              )
            ),
            pw.SizedBox(height: 5),
            pw.Text("Período analisado: $periodoStr", style: pw.TextStyle(fontSize: 10)),
            pw.Text("Filtros aplicados: Bloco: ${_selectedBloco?['nome'] ?? 'Todos'} | Andar: ${_selectedAndar ?? 'Todos'} | Unidade: ${_selectedUnidade?['identificacao'] ?? 'Todas'}", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 15),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              // Pesos para caber bonitinho na A4 Retrato
              columnWidths: {
                0: const pw.FlexColumnWidth(1.7), // Data
                1: const pw.FlexColumnWidth(1.0), // Bloco
                2: const pw.FlexColumnWidth(1.2), // Unidade
                3: const pw.FlexColumnWidth(1.5), // Medidor
                4: const pw.FlexColumnWidth(1.2), // Ant.
                5: const pw.FlexColumnWidth(1.2), // Atual
                6: const pw.FlexColumnWidth(1.3), // Consumo
                7: const pw.FlexColumnWidth(1.5), // Faturado
              },
              children: [
                // O repeat: true FAZ A MÁGICA DE REPETIR O CABEÇALHO NA QUEBRA DE PÁGINA
                pw.TableRow(
                  repeat: true,
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    buildPdfHeader('Data/Hora'), buildPdfHeader('Bloco'), buildPdfHeader('Unid.'),
                    buildPdfHeader('Medidor'), buildPdfHeader('Ant.'), buildPdfHeader('Atual'),
                    buildPdfHeader('Cons.(m³)'), buildPdfHeader('Faturado(R\$)'),
                  ]
                ),
                ..._leiturasFiltradas.map((item) => pw.TableRow(
                  children: [
                    buildPdfCell(item['data_formatada']?.toString() ?? '-'),
                    buildPdfCell(item['bloco']?.toString() ?? '-'),
                    buildPdfCell(item['unidade']?.toString() ?? '-'),
                    buildPdfChip(item['tipo_medidor']?.toString() ?? '-'),
                    buildPdfCell(_formatarMedicao(item['leitura_anterior'])),
                    buildPdfCell(_formatarMedicao(item['valor_lido'])),
                    buildPdfCell(_formatarMedicao(item['consumo'])),
                    buildPdfCell("R\$ ${_formatarMoeda(item['valor_total_faturado'])}"),
                  ]
                )),
                // ==========================================
                // NOVA LINHA DE SOMATÓRIO TOTAL NO FINAL
                // ==========================================
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    buildPdfCell(''), buildPdfCell(''), buildPdfCell(''), buildPdfCell(''),
                    buildPdfCell(''), buildPdfCell(''), 
                    buildPdfCell('TOTAL GERAL:', alignment: pw.Alignment.centerRight, isBold: true),
                    buildPdfCell("R\$ ${_formatarMoeda(totalFaturado)}", isBold: true, textColor: PdfColors.green800),
                  ]
                )
              ]
            ),
            pw.SizedBox(height: 15),
            pw.Divider(thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
              children: [
                pw.Text("Gerado em: $dataGeracao", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                pw.Text("Total de registros exibidos: ${_leiturasFiltradas.length}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))
              ]
            )
          ];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: "Relatorio_CondoLogic_Faturamento");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Central de Relatórios', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
        const SizedBox(height: 5),
        const Text('Utilize os filtros em cascata abaixo para refinar os resultados antes de exportar.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),

        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        value: _selectedTenantId,
                        decoration: const InputDecoration(labelText: '1. Condomínio', border: OutlineInputBorder(), prefixIcon: Icon(Icons.apartment)),
                        items: _condominios.map<DropdownMenuItem<int>>((item) {
                          return DropdownMenuItem<int>(value: item['id'], child: Text(item['nome']));
                        }).toList(),
                        onChanged: (val) {
                          setState(() { _selectedTenantId = val; _jaBuscou = false; });
                          _carregarBlocos(val!);
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _selecionarPeriodo,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: '2. Período de Análise', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month)),
                          child: Text("${DateFormat('dd/MM/yyyy').format(_dataSelecionada.start)} até ${DateFormat('dd/MM/yyyy').format(_dataSelecionada.end)}", style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _buscarRelatorio,
                        icon: const Icon(Icons.search, color: Colors.white),
                        label: const Text('BUSCAR DADOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], padding: const EdgeInsets.symmetric(horizontal: 24)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Map<String, dynamic>?>(
                        value: _selectedBloco,
                        decoration: const InputDecoration(labelText: '3. Bloco / Torre', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(value: null, child: Text("TODOS OS BLOCOS", style: TextStyle(fontWeight: FontWeight.bold))),
                          ..._blocos.map((item) => DropdownMenuItem(value: item, child: Text(item['nome']))),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedBloco = val);
                          if (val != null) _carregarUnidadesEAndares(val['id']);
                          else setState(() { _selectedAndar = null; _selectedUnidade = null; _andares = []; _unidades = []; });
                          _aplicarFiltrosLocais();
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _selectedAndar,
                        decoration: const InputDecoration(labelText: '4. Andar', border: OutlineInputBorder()),
                        items: _selectedBloco == null ? null : [
                          const DropdownMenuItem(value: null, child: Text("TODOS OS ANDARES", style: TextStyle(fontWeight: FontWeight.bold))),
                          ..._andares.map((andar) => DropdownMenuItem(value: andar, child: Text(andar))),
                        ],
                        onChanged: (val) {
                          setState(() { _selectedAndar = val; _selectedUnidade = null; });
                          _aplicarFiltrosLocais();
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonFormField<Map<String, dynamic>?>(
                        value: _selectedUnidade,
                        decoration: const InputDecoration(labelText: '5. Unidade', border: OutlineInputBorder()),
                        items: (_selectedBloco == null || _selectedAndar == null) ? null : [
                          const DropdownMenuItem(value: null, child: Text("TODAS AS UNIDADES", style: TextStyle(fontWeight: FontWeight.bold))),
                          ..._unidades.where((u) => _selectedAndar == null || (u['andar']?.toString() ?? 'Térreo') == _selectedAndar).map(
                            (item) => DropdownMenuItem(value: item, child: Text("Unidade ${item['identificacao']}"))
                          ),
                        ],
                        onChanged: (_selectedBloco == null || _selectedAndar == null) ? null : (val) {
                          setState(() => _selectedUnidade = val);
                          _aplicarFiltrosLocais();
                        },
                        disabledHint: Text(_selectedAndar == null ? "Indisponível (Andar não selecionado)" : "Selecione a Unidade", style: TextStyle(color: Colors.grey[500])),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_leiturasFiltradas.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("${_leiturasFiltradas.length} registos encontrados", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _exportarExcel,
                icon: const Icon(Icons.table_view, color: Colors.white),
                label: const Text('BAIXAR EXCEL (.XLSX)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
              ),
              const SizedBox(width: 15),
              ElevatedButton.icon(
                onPressed: _imprimirPDF,
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text('IMPRIMIR / PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
              ),
            ],
          ),
        const SizedBox(height: 20),
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : !_jaBuscou 
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.manage_search, size: 80, color: Colors.grey[300]), const SizedBox(height: 10), Text("Selecione o período e clique em BUSCAR DADOS", style: TextStyle(color: Colors.grey[600], fontSize: 16))]))
              : _leiturasBrutas.isEmpty 
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.event_busy, size: 80, color: Colors.grey[300]), const SizedBox(height: 10), Text("A base de dados não retornou leituras para este condomínio.", style: TextStyle(color: Colors.red[600], fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 5), const Text("Certifique-se que o Bloco/Condomínio correto foi escolhido.", style: TextStyle(color: Colors.grey))]))
                : _leiturasFiltradas.isEmpty 
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.filter_alt_off, size: 80, color: Colors.grey[300]), const SizedBox(height: 10), const Text("Existem leituras registadas, mas nenhuma caiu nos seus filtros.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]))
                  : Card( 
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
                            child: Row(
                              children: [
                                _buildHeaderCell('Data / Hora', flex: 2),
                                _buildHeaderCell('Bloco / Unidade', flex: 2),
                                _buildHeaderCell('Medidor', flex: 2),
                                _buildHeaderCell('Leitura Ant.', flex: 2),
                                _buildHeaderCell('Leitura Atual', flex: 2),
                                _buildHeaderCell('Consumo', flex: 2, color: Colors.deepOrange),
                                _buildHeaderCell('Faturado (R\$)', flex: 2, color: Colors.green),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _leiturasFiltradas.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final l = _leiturasFiltradas[index];
                                Color? corFundo = Colors.blue[600];
                                String tipoStr = l['tipo_medidor']?.toString().toLowerCase() ?? '';
                                if (tipoStr.contains('quente')) corFundo = Colors.red[600];
                                else if (tipoStr.contains('gas') || tipoStr.contains('gás')) corFundo = Colors.orange;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                  child: Row(
                                    children: [
                                      _buildDataCell(Text(l['data_formatada'] ?? l['data_leitura'] ?? '-', style: const TextStyle(fontSize: 13)), flex: 2),
                                      _buildDataCell(Text("${l['bloco'] ?? l['bloco_nome'] ?? '-'} - ${l['unidade'] ?? l['identificacao'] ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), flex: 2),
                                      _buildDataCell(Align(alignment: Alignment.centerLeft, child: Chip(label: Text((l['tipo_medidor'] ?? 'Desc.').toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: corFundo, padding: EdgeInsets.zero)), flex: 2),
                                      _buildDataCell(Text(_formatarMedicao(l['leitura_anterior']), style: const TextStyle(fontSize: 13)), flex: 2),
                                      _buildDataCell(Text(_formatarMedicao(l['valor_lido']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), flex: 2),
                                      _buildDataCell(Text('${_formatarMedicao(l['consumo'])} m³', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13)), flex: 2),
                                      _buildDataCell(Text('R\$ ${_formatarMoeda(l['valor_total_faturado'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)), flex: 2),
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
      ],
    );
  }
}