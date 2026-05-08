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
import 'package:excel/excel.dart' as ex; // Prefixo ex. para evitar conflito com Border do Flutter
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
  bool _isLoading = false;
  String _mesReferencia = DateFormat('MM/yyyy').format(DateTime.now());

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

  Future<void> _buscarDadosParaExportacao() async {
    if (widget.condominioSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um condomínio no painel principal primeiro!'), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dados = await _apiService.getLeiturasParaExportacao(
        widget.condominioSelecionado!['id'], 
        _mesReferencia
      );

      if (mounted) {
        setState(() { 
          _leituras = dados; 
          _isLoading = false; 
        });
        if (_leituras.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado encontrado para este mês.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${_leituras.length} registros carregados!'), 
            backgroundColor: Colors.green
          ));
        }
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _exportarExcelPuro() {
    if (_leituras.isEmpty) return;
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel['Leituras'];
    excel.setDefaultSheet('Leituras');

    List<ex.CellValue> header = [
      ex.TextCellValue("Bloco"), ex.TextCellValue("Unidade"), ex.TextCellValue("Tipo"),
      ex.TextCellValue("Mês"), ex.TextCellValue("Data Leitura"), ex.TextCellValue("Leitura Anterior"),
      ex.TextCellValue("Leitura Atual"), ex.TextCellValue("Consumo"), ex.TextCellValue("Custo"),
      ex.TextCellValue("Custo Adicional Total"), ex.TextCellValue("Houve Troca de Medidor"),
      ex.TextCellValue("Validade Medidor"), ex.TextCellValue("Observação"), ex.TextCellValue("Imagem")
    ];
    sheet.appendRow(header);

    for (var row in _leituras) {
      sheet.appendRow([
        ex.TextCellValue(row['bloco']?.toString() ?? ""),
        ex.TextCellValue(row['unidade']?.toString() ?? ""),
        ex.TextCellValue(row['tipo_medidor']?.toString() ?? ""),
        ex.TextCellValue(row['mes_referencia']?.toString() ?? ""),
        ex.TextCellValue(row['data_leitura_formatada']?.toString() ?? ""),
        ex.DoubleCellValue(double.tryParse(row['leitura_anterior']?.toString() ?? "0") ?? 0.0),
        ex.DoubleCellValue(double.tryParse(row['valor_lido']?.toString() ?? "0") ?? 0.0),
        ex.DoubleCellValue(double.tryParse(row['consumo']?.toString() ?? "0") ?? 0.0),
        ex.DoubleCellValue(double.tryParse(row['custo_unitario']?.toString() ?? "0") ?? 0.0),
        ex.DoubleCellValue(double.tryParse(row['custo_adicional']?.toString() ?? "0") ?? 0.0),
        ex.TextCellValue((row['trocou_medidor'] == true) ? "Sim" : "Não"),
        ex.TextCellValue(row['validade_medidor']?.toString() ?? ""),
        ex.TextCellValue(row['observacao_auditoria']?.toString() ?? ""),
        ex.TextCellValue(row['foto_url']?.toString() ?? "")
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", "Exportacao_${widget.condominioSelecionado!['nome']}_${_mesReferencia.replaceAll('/', '_')}.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  void _exportarCSV() {
    if (_leituras.isEmpty) return;
    List<List<dynamic>> rows = [["Bloco", "Unidade", "Tipo", "Mês", "Data Leitura", "Leitura Anterior", "Leitura Atual", "Consumo", "Custo", "Custo Adicional Total", "Houve Troca de Medidor", "Validade Medidor", "Observação", "Imagem"]];
    for (var row in _leituras) {
      rows.add([row['bloco'] ?? '-', row['unidade'] ?? '-', row['tipo_medidor'] ?? '-', row['mes_referencia'] ?? '-', row['data_leitura_formatada'] ?? '-', _formatarMedicao(row['leitura_anterior']), _formatarMedicao(row['valor_lido']), _formatarMedicao(row['consumo']), _formatarMoeda(row['custo_unitario']), _formatarMoeda(row['custo_adicional']), (row['trocou_medidor'] == true) ? "Sim" : "Não", row['validade_medidor'] ?? '', row['observacao_auditoria'] ?? '', row['foto_url'] ?? '']);
    }
    String csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    final bytes = [239, 187, 191] + utf8.encode(csv); 
    final blob = html.Blob([Uint8List.fromList(bytes)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)..setAttribute("download", "Exportacao_${_mesReferencia.replaceAll('/', '_')}.csv")..click();
    html.Url.revokeObjectUrl(url);
  }

  void _exportarXML() {
    if (_leituras.isEmpty) return;
    final nomeCond = widget.condominioSelecionado!['nome'];
    StringBuffer xml = StringBuffer();
    xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    xml.writeln('<ExportacaoCondoLogic><Condominio>$nomeCond</Condominio><Registros>');
    for (var l in _leituras) {
      xml.writeln('  <Leitura><Unidade>${l['unidade']}</Unidade><Tipo>${l['tipo_medidor']}</Tipo><Consumo>${l['consumo']}</Consumo><Valor>${l['valor_total_faturado'] ?? l['custo_unitario']}</Valor></Leitura>');
    }
    xml.writeln('</Registros></ExportacaoCondoLogic>');
    final bytes = utf8.encode(xml.toString());
    final blob = html.Blob([Uint8List.fromList(bytes)], 'application/xml');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)..setAttribute("download", "Exportacao.xml")..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _imprimirPDF() async {
    if (_leituras.isEmpty) return;
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (pw.Context context) => [
      pw.Header(level: 0, child: pw.Text("Extrato de Leituras - ${widget.condominioSelecionado!['nome']}")),
      pw.TableHelper.fromTextArray(data: <List<String>>[
        <String>['Bloco', 'Unid.', 'Tipo', 'Consumo', 'Custo'],
        ..._leituras.map((item) => [item['bloco'] ?? '', item['unidade'] ?? '', item['tipo_medidor'] ?? '', _formatarMedicao(item['consumo']), _formatarMoeda(item['custo_unitario'])])
      ]),
    ]));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Integração e Exportação de Dados', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.grey[300]!)), // Border do Flutter
                    child: Text("Condomínio: ${widget.condominioSelecionado?['nome'] ?? 'Selecione'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: _mesReferencia,
                    onChanged: (v) => _mesReferencia = v,
                    decoration: const InputDecoration(labelText: 'Mês (MM/YYYY)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 15),
                ElevatedButton(onPressed: _buscarDadosParaExportacao, child: const Text('CARREGAR')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        if (_isLoading) const Center(child: CircularProgressIndicator())
        else if (_leituras.isNotEmpty)
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _buildExportCard(icon: Icons.table_view, color: Colors.green[800]!, title: "Excel Puro (.xlsx)", subtitle: "Formato oficial.", onTap: _exportarExcelPuro),
              _buildExportCard(icon: Icons.table_chart, color: Colors.green, title: "Planilha CSV", subtitle: "Separado por (;).", onTap: _exportarCSV),
              _buildExportCard(icon: Icons.code, color: Colors.orange, title: "Arquivo XML", subtitle: "Integração ERP.", onTap: _exportarXML),
              _buildExportCard(icon: Icons.picture_as_pdf, color: Colors.red, title: "Relatório PDF", subtitle: "Conferência.", onTap: _imprimirPDF),
            ],
          )
      ],
    );
  }

  Widget _buildExportCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Container(width: 260, padding: const EdgeInsets.all(20), child: Column(children: [Icon(icon, size: 50, color: color), const SizedBox(height: 15), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(fontSize: 11)), const SizedBox(height: 15), ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: color), child: const Text("BAIXAR", style: TextStyle(color: Colors.white)))])),
      ),
    );
  }
}