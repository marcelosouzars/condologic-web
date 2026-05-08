// ========================= exportacao_screen_web.dart 

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import '../services/api_service_web.dart';

class ExportacaoScreenWeb extends StatefulWidget {
  final Map<String, dynamic>? usuarioLogado;
  final Map<String, dynamic>? condominioSelecionado;

  const ExportacaoScreenWeb({
    super.key, 
    this.usuarioLogado, 
    this.condominioSelecionado
  });

  @override
  State<ExportacaoScreenWeb> createState() => _ExportacaoScreenWebState();
}

class _ExportacaoScreenWebState extends State<ExportacaoScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  
  List<dynamic> _leituras = [];
  
  // Período de datas reativado
  DateTimeRange _dataSelecionada = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Não precisamos mais carregar a lista de condomínios aqui, 
    // pois usaremos o widget.condominioSelecionado vindo do painel.
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
                  const Text("Defina a data inicial e final para o relatório:", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                                context: context, 
                                initialDate: inicioTemp, 
                                firstDate: DateTime(2020), 
                                lastDate: DateTime.now().add(const Duration(days: 365))
                            );
                            if (picked != null) setStateModal(() => inicioTemp = picked);
                          },
                          child: InputDecorator(
                              decoration: const InputDecoration(labelText: "Data Inicial", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today, size: 20)), 
                              child: Text(DateFormat('dd/MM/yyyy').format(inicioTemp), style: const TextStyle(fontWeight: FontWeight.bold))
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Icon(Icons.arrow_forward, color: Colors.grey),
                      const SizedBox(width: 15),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                                context: context, 
                                initialDate: fimTemp, 
                                firstDate: DateTime(2020), 
                                lastDate: DateTime.now().add(const Duration(days: 365))
                            );
                            if (picked != null) setStateModal(() => fimTemp = picked);
                          },
                          child: InputDecorator(
                              decoration: const InputDecoration(labelText: "Data Final", border: OutlineInputBorder(), prefixIcon: Icon(Icons.event, size: 20)), 
                              child: Text(DateFormat('dd/MM/yyyy').format(fimTemp), style: const TextStyle(fontWeight: FontWeight.bold))
                          ),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A Data Final não pode ser anterior à Inicial."), backgroundColor: Colors.red));
                      return;
                    }
                    setState(() => _dataSelecionada = DateTimeRange(start: inicioTemp, end: fimTemp));
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

  Future<void> _buscarDadosParaExportacao() async {
    if (widget.condominioSelecionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione um condomínio no painel superior.'), backgroundColor: Colors.orange));
        return;
    }

    setState(() => _isLoading = true);
    try {
      final dtInicioStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.start);
      final dtFimStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.end);
      
      // Usa o ID do condomínio que já está selecionado no sistema
      final tenantId = widget.condominioSelecionado!['id'];
      
      final dados = await _apiService.getLeituras(tenantId, dtInicio: dtInicioStr, dtFim: dtFimStr);
      
      if (mounted) {
        setState(() { _leituras = dados; _isLoading = false; });
        if (_leituras.isEmpty) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado encontrado para o período.')));
        else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_leituras.length} registros prontos!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _exportarCSV() {
    if (_leituras.isEmpty) return;
    final nomeCond = widget.condominioSelecionado?['nome'] ?? 'Condominio';
    List<List<dynamic>> rows = [["Condomínio", "Data", "Bloco", "Unidade", "Medidor", "Leitura Anterior", "Leitura Atual", "Consumo m3", "Faturado R\$", "Status"]];
    for (var row in _leituras) {
      rows.add([nomeCond, row['data_formatada'] ?? '-', row['bloco'] ?? '-', row['unidade'] ?? '-', row['tipo_medidor'].toString().toUpperCase(), _formatarMedicao(row['leitura_anterior']), _formatarMedicao(row['valor_lido']), _formatarMedicao(row['consumo']), _formatarMoeda(row['valor_total_faturado']), row['status_leitura'] ?? 'Concluído']);
    }
    String csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    final bytes = [239, 187, 191] + utf8.encode(csv); 
    final blob = html.Blob([Uint8List.fromList(bytes)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)..setAttribute("download", "Exportacao_${DateFormat('ddMMyyyy').format(DateTime.now())}.csv")..click();
    html.Url.revokeObjectUrl(url);
  }

  String _escaparXML(String text) {
    return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
  }

  void _exportarXML() {
    if (_leituras.isEmpty) return;
    final nomeCond = widget.condominioSelecionado?['nome'] ?? 'Condominio';
    StringBuffer xml = StringBuffer();
    xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    xml.writeln('<ExportacaoCondoLogic>');
    xml.writeln('  <Condominio>${_escaparXML(nomeCond)}</Condominio>');
    xml.writeln('  <DataGeracao>${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}</DataGeracao>');
    xml.writeln('  <Registros>');
    for (var l in _leituras) {
      xml.writeln('    <Leitura>');
      xml.writeln('      <Data>${l['data_formatada']}</Data>');
      xml.writeln('      <Bloco>${_escaparXML(l['bloco'] ?? '')}</Bloco>');
      xml.writeln('      <Unidade>${_escaparXML(l['unidade'] ?? '')}</Unidade>');
      xml.writeln('      <TipoMedidor>${_escaparXML(l['tipo_medidor'].toString().toUpperCase())}</TipoMedidor>');
      xml.writeln('      <LeituraAnterior>${_formatarMedicao(l['leitura_anterior'])}</LeituraAnterior>');
      xml.writeln('      <ValorLido>${_formatarMedicao(l['valor_lido'])}</ValorLido>');
      xml.writeln('      <Consumo>${_formatarMedicao(l['consumo'])}</Consumo>');
      xml.writeln('      <Faturado>${_formatarMoeda(l['valor_total_faturado'])}</Faturado>');
      xml.writeln('    </Leitura>');
    }
    xml.writeln('  </Registros>');
    xml.writeln('</ExportacaoCondoLogic>');
    final bytes = utf8.encode(xml.toString());
    final blob = html.Blob([Uint8List.fromList(bytes)], 'application/xml');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)..setAttribute("download", "Exportacao_${DateFormat('ddMMyyyy').format(DateTime.now())}.xml")..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _imprimirPDF() async {
    if (_leituras.isEmpty) return;
    final doc = pw.Document();
    final nomeCond = widget.condominioSelecionado?['nome'] ?? 'Condominio';
    final dataGeracao = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final periodoStr = "${DateFormat('dd/MM/yyyy').format(_dataSelecionada.start)} a ${DateFormat('dd/MM/yyyy').format(_dataSelecionada.end)}";

    double totalFaturado = 0.0;
    for (var l in _leituras) {
      totalFaturado += double.tryParse(l['valor_total_faturado']?.toString() ?? '0') ?? 0.0;
    }
    
    pw.Widget buildPdfHeader(String text) {
      return pw.Container(alignment: pw.Alignment.centerLeft, padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: pw.Text(text, style: pw.TextStyle(fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold)));
    }

    pw.Widget buildPdfCell(String text, {pw.Alignment alignment = pw.Alignment.centerLeft, bool isBold = false, PdfColor textColor = PdfColors.black}) {
      return pw.Container(alignment: alignment, padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4), child: pw.Text(text, style: pw.TextStyle(fontSize: 7, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: textColor)));
    }

    pw.Widget buildPdfChip(String tipo) {
      PdfColor corFundo = PdfColors.blue600;
      String texto = tipo.toUpperCase();
      if (tipo.toLowerCase().contains('quente')) corFundo = PdfColors.red600;
      else if (tipo.toLowerCase().contains('gas') || tipo.toLowerCase().contains('gás')) corFundo = PdfColors.orange600;

      return pw.Container(
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.all(2),
        child: pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: pw.BoxDecoration(color: corFundo, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3))), child: pw.Text(texto, style: pw.TextStyle(color: PdfColors.white, fontSize: 6, fontWeight: pw.FontWeight.bold)))
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("Extrato de Leituras para Integração", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.Text(nomeCond, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ])),
            pw.SizedBox(height: 5),
            pw.Text("Período analisado: $periodoStr", style: pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 15),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.7), 1: const pw.FlexColumnWidth(1.0), 2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.5), 4: const pw.FlexColumnWidth(1.2), 5: const pw.FlexColumnWidth(1.2),
                6: const pw.FlexColumnWidth(1.3), 7: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  repeat: true,
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    buildPdfHeader('Data/Hora'), buildPdfHeader('Bloco'), buildPdfHeader('Unid.'),
                    buildPdfHeader('Medidor'), buildPdfHeader('Ant.'), buildPdfHeader('Atual'),
                    buildPdfHeader('Cons.(m³)'), buildPdfHeader('Faturado(R\$)'),
                  ]
                ),
                ..._leituras.map((item) => pw.TableRow(
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
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("Gerado em: $dataGeracao", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
              pw.Text("Total de registros exibidos: ${_leituras.length}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))
            ])
          ];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: "Exportacao_CondoLogic_Faturamento");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Integração e Exportação de Dados', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
        const SizedBox(height: 5),
        const Text('Extraia as leituras do sistema para importar no seu software de gestão financeira.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Identificação visual do condomínio ativo (não é mais um Dropdown)
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!)
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.apartment, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Condomínio: ${widget.condominioSelecionado?['nome'] ?? 'Selecione no painel'}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: _selecionarPeriodo,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Período das Leituras', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month)),
                      child: Text("${DateFormat('dd/MM/yyyy').format(_dataSelecionada.start)} até ${DateFormat('dd/MM/yyyy').format(_dataSelecionada.end)}"),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _buscarDadosParaExportacao,
                    icon: const Icon(Icons.downloading, color: Colors.white),
                    label: const Text('CARREGAR DADOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], padding: const EdgeInsets.symmetric(horizontal: 24)),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 30),

        if (_isLoading) 
           const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_leituras.isNotEmpty)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Escolha o formato de saída:", style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildExportCard(icon: Icons.table_chart, color: Colors.green, title: "Planilha Excel (CSV)", subtitle: "Para edição manual ou filtros rápidos.", onTap: _exportarCSV),
                    _buildExportCard(icon: Icons.code, color: Colors.orange, title: "Arquivo XML", subtitle: "Para integração direta com ERPs e contabilidade.", onTap: _exportarXML),
                    _buildExportCard(icon: Icons.picture_as_pdf, color: Colors.red, title: "Documento PDF", subtitle: "Para impressão e arquivo físico.", onTap: _imprimirPDF),
                  ],
                ),
              ],
            ),
          )
      ],
    );
  }

  Widget _buildExportCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 60, color: color),
              const SizedBox(height: 15),
              Text(title, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(backgroundColor: color, minimumSize: const Size(double.infinity, 40)),
                child: const Text("BAIXAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}