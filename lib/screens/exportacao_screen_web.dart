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
import 'package:excel/excel.dart'; // Adicionado para Excel Puro
import '../services/api_service_web.dart';

class ExportacaoScreenWeb extends StatefulWidget {
  // Alterado para receber o condomínio selecionado do contexto global
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
  
  // Mês de referência padrão (MM/YYYY)
  String _mesReferencia = DateFormat('MM/yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    // Não carregamos mais a lista de condomínios aqui para evitar erro de seleção
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

  Future<void> _buscarDadosParaExportacao() async {
    if (widget.condominioSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um condomínio no painel principal primeiro!'), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Usamos a nova rota de exportação que segue o layout da administradora
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
            content: Text('${_leituras.length} registros carregados para ${widget.condominioSelecionado!['nome']}!'), 
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

  // NOVA FUNÇÃO: EXCEL PURO (.XLSX) NO PADRÃO DA ADMINISTRADORA
  void _exportarExcelPuro() {
    if (_leituras.isEmpty) return;

    var excel = Excel.createExcel();
    Sheet sheet = excel['Leituras'];
    excel.setDefaultSheet('Leituras');

    // Cabeçalho conforme solicitado
    List<CellValue> header = [
      TextCellValue("Bloco"), TextCellValue("Unidade"), TextCellValue("Tipo"),
      TextCellValue("Mês"), TextCellValue("Data Leitura"), TextCellValue("Leitura Anterior"),
      TextCellValue("Leitura Atual"), TextCellValue("Consumo"), TextCellValue("Custo"),
      TextCellValue("Custo Adicional Total"), TextCellValue("Houve Troca de Medidor"),
      TextCellValue("Validade Medidor"), TextCellValue("Observação"), TextCellValue("Imagem")
    ];
    sheet.appendRow(header);

    for (var row in _leituras) {
      sheet.appendRow([
        TextCellValue(row['bloco']?.toString() ?? ""),
        TextCellValue(row['unidade']?.toString() ?? ""),
        TextCellValue(row['tipo_medidor']?.toString() ?? ""),
        TextCellValue(row['mes_referencia']?.toString() ?? ""),
        TextCellValue(row['data_leitura_formatada']?.toString() ?? ""),
        DoubleCellValue(double.tryParse(row['leitura_anterior']?.toString() ?? "0") ?? 0.0),
        DoubleCellValue(double.tryParse(row['valor_lido']?.toString() ?? "0") ?? 0.0),
        DoubleCellValue(double.tryParse(row['consumo']?.toString() ?? "0") ?? 0.0),
        DoubleCellValue(double.tryParse(row['custo_unitario']?.toString() ?? "0") ?? 0.0),
        DoubleCellValue(double.tryParse(row['custo_adicional']?.toString() ?? "0") ?? 0.0),
        TextCellValue((row['trocou_medidor'] == true) ? "Sim" : "Não"),
        TextCellValue(row['validade_medidor']?.toString() ?? ""),
        TextCellValue(row['observacao_auditoria']?.toString() ?? ""),
        TextCellValue(row['foto_url']?.toString() ?? "")
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Exportacao_${widget.condominioSelecionado!['nome']}_${_mesReferencia.replaceAll('/', '_')}.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  void _exportarCSV() {
    if (_leituras.isEmpty) return;
    
    // Cabeçalho ajustado para o novo padrão
    List<List<dynamic>> rows = [[
      "Bloco", "Unidade", "Tipo", "Mês", "Data Leitura", "Leitura Anterior",
      "Leitura Atual", "Consumo", "Custo", "Custo Adicional Total",
      "Houve Troca de Medidor", "Validade Medidor", "Observação", "Imagem"
    ]];

    for (var row in _leituras) {
      rows.add([
        row['bloco'] ?? '-',
        row['unidade'] ?? '-',
        row['tipo_medidor'] ?? '-',
        row['mes_referencia'] ?? '-',
        row['data_leitura_formatada'] ?? '-',
        _formatarMedicao(row['leitura_anterior']),
        _formatarMedicao(row['valor_lido']),
        _formatarMedicao(row['consumo']),
        _formatarMoeda(row['custo_unitario']),
        _formatarMoeda(row['custo_adicional']),
        (row['trocou_medidor'] == true) ? "Sim" : "Não",
        row['validade_medidor'] ?? '',
        row['observacao_auditoria'] ?? '',
        row['foto_url'] ?? ''
      ]);
    }

    String csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    final bytes = [239, 187, 191] + utf8.encode(csv); 
    final blob = html.Blob([Uint8List.fromList(bytes)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)..setAttribute("download", "Exportacao_${_mesReferencia.replaceAll('/', '_')}.csv")..click();
    html.Url.revokeObjectUrl(url);
  }

  void _exportarXML() {
    if (_leituras.isEmpty) return;
    final nomeCond = widget.condominioSelecionado!['nome'];
    StringBuffer xml = StringBuffer();
    xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    xml.writeln('<ExportacaoCondoLogic>');
    xml.writeln('  <Condominio>${nomeCond}</Condominio>');
    xml.writeln('  <Registros>');
    for (var l in _leituras) {
      xml.writeln('    <Leitura>');
      xml.writeln('      <Unidade>${l['unidade']}</Unidade>');
      xml.writeln('      <Tipo>${l['tipo_medidor']}</Tipo>');
      xml.writeln('      <Consumo>${l['consumo']}</Consumo>');
      xml.writeln('      <Valor>${l['valor_total_faturado'] ?? l['custo_unitario']}</Valor>');
      xml.writeln('    </Leitura>');
    }
    xml.writeln('  </Registros>');
    xml.writeln('</ExportacaoCondoLogic>');
    final bytes = utf8.encode(xml.toString());
    final blob = html.Blob([Uint8List.fromList(bytes)], 'application/xml');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)..setAttribute("download", "Exportacao_${_mesReferencia.replaceAll('/', '_')}.xml")..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _imprimirPDF() async {
    if (_leituras.isEmpty) return;
    final doc = pw.Document();
    final nomeCond = widget.condominioSelecionado!['nome'];
    final dataGeracao = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("Extrato de Leituras - $nomeCond", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.Text("Mês: $_mesReferencia", style: pw.TextStyle(fontSize: 10)),
            ])),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 7),
              data: <List<String>>[
                <String>['Bloco', 'Unid.', 'Tipo', 'Anterior', 'Atual', 'Consumo', 'Custo'],
                ..._leituras.map((item) => [
                  item['bloco']?.toString() ?? '',
                  item['unidade']?.toString() ?? '',
                  item['tipo_medidor']?.toString() ?? '',
                  _formatarMedicao(item['leitura_anterior']),
                  _formatarMedicao(item['valor_lido']),
                  _formatarMedicao(item['consumo']),
                  _formatarMoeda(item['custo_unitario']),
                ])
              ],
            ),
          ];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: "Exportacao_CondoLogic");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Integração e Exportação de Dados', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
        const SizedBox(height: 5),
        const Text('Extraia as leituras para cobrança no padrão das administradoras.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Informação Fixa do Condomínio (Trava de Segurança)
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.grey[300]!)
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.apartment, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Condomínio: ${widget.condominioSelecionado?['nome'] ?? 'Selecione no painel'}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // Mês de Referência
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: _mesReferencia,
                    onChanged: (v) => _mesReferencia = v,
                    decoration: const InputDecoration(
                      labelText: 'Mês de Referência (MM/YYYY)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_month)
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _buscarDadosParaExportacao,
                    icon: const Icon(Icons.refresh, color: Colors.white),
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Escolha o formato de saída:", style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      _buildExportCard(icon: Icons.table_view, color: Colors.green[800]!, title: "Excel Puro (.xlsx)", subtitle: "Formato oficial para administradoras.", onTap: _exportarExcelPuro),
                      _buildExportCard(icon: Icons.table_chart, color: Colors.green, title: "Planilha CSV", subtitle: "Separado por ponto e vírgula (;).", onTap: _exportarCSV),
                      _buildExportCard(icon: Icons.code, color: Colors.orange, title: "Arquivo XML", subtitle: "Integração direta com ERPs.", onTap: _exportarXML),
                      _buildExportCard(icon: Icons.picture_as_pdf, color: Colors.red, title: "Relatório PDF", subtitle: "Para conferência visual e arquivo.", onTap: _imprimirPDF),
                    ],
                  ),
                ],
              ),
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
          width: 260,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 50, color: color),
              const SizedBox(height: 15),
              Text(title, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
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