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
  
  DateTimeRange _dataSelecionada = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  bool _isLoading = false;

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
    // Tenta pegar o ID do condomínio selecionado ou do usuário logado (SaaS)
    int? tenantId = widget.condominioSelecionado?['id'] ?? widget.usuarioLogado?['tenant_id'];

    if (tenantId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Não foi possível identificar o condomínio ativo.'), backgroundColor: Colors.red));
        return;
    }

    setState(() => _isLoading = true);
    try {
      final dtInicioStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.start);
      final dtFimStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.end);
      
      final dados = await _apiService.getLeituras(tenantId, dtInicio: dtInicioStr, dtFim: dtFimStr);
      
      if (mounted) {
        setState(() { _leituras = dados; _isLoading = false; });
        if (_leituras.isEmpty) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado encontrado para este período.')));
        else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_leituras.length} registros prontos!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar dados: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _exportarCSV() {
    if (_leituras.isEmpty) return;
    final nomeCond = widget.condominioSelecionado?['nome'] ?? 'Exportacao';
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

  // Métodos XML e PDF mantidos para garantir a Regra de Ouro
  void _exportarXML() {
    if (_leituras.isEmpty) return;
    final nomeCond = widget.condominioSelecionado?['nome'] ?? 'Condominio';
    StringBuffer xml = StringBuffer();
    xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    xml.writeln('<ExportacaoCondoLogic>');
    xml.writeln('  <Condominio>$nomeCond</Condominio>');
    xml.writeln('  <Registros>');
    for (var l in _leituras) {
      xml.writeln('    <Leitura><Unidade>${l['unidade']}</Unidade><Consumo>${l['consumo']}</Consumo></Leitura>');
    }
    xml.writeln('  </Registros></ExportacaoCondoLogic>');
    final bytes = utf8.encode(xml.toString());
    final blob = html.Blob([Uint8List.fromList(bytes)], 'application/xml');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)..setAttribute("download", "Exportacao.xml")..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _imprimirPDF() async {
    if (_leituras.isEmpty) return;
    final doc = pw.Document();
    final nomeCond = widget.condominioSelecionado?['nome'] ?? 'Condominio';
    doc.addPage(pw.MultiPage(build: (pw.Context context) => [
      pw.Header(level: 0, child: pw.Text("Extrato de Leituras - $nomeCond")),
      pw.TableHelper.fromTextArray(data: <List<String>>[
        <String>['Bloco', 'Unid.', 'Tipo', 'Consumo'],
        ..._leituras.map((item) => [item['bloco'] ?? '', item['unidade'] ?? '', item['tipo_medidor'] ?? '', _formatarMedicao(item['consumo'])])
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
                // EXIBIÇÃO DO CONDOMÍNIO ATIVO (Somente Leitura)
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
                            "Condomínio: ${widget.condominioSelecionado?['nome'] ?? 'Configurado no Painel'}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // SELETOR DE DATAS
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
                    _buildExportCard(icon: Icons.table_chart, color: Colors.green, title: "Planilha Excel (CSV)", subtitle: "Para edição manual.", onTap: _exportarCSV),
                    _buildExportCard(icon: Icons.code, color: Colors.orange, title: "Arquivo XML", subtitle: "Integração ERP.", onTap: _exportarXML),
                    _buildExportCard(icon: Icons.picture_as_pdf, color: Colors.red, title: "Documento PDF", subtitle: "Impressão.", onTap: _imprimirPDF),
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 15),
              ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: color), child: const Text("BAIXAR", style: TextStyle(color: Colors.white))),
            ],
          ),
        ),
      ),
    );
  }
}