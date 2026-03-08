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
  const ExportacaoScreenWeb({super.key});

  @override
  State<ExportacaoScreenWeb> createState() => _ExportacaoScreenWebState();
}

class _ExportacaoScreenWebState extends State<ExportacaoScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  
  List<dynamic> _leituras = [];
  List<dynamic> _condominios = [];
  int? _selectedTenantId;
  
  DateTimeRange _dataSelecionada = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _carregarCondominios();
  }

  Future<void> _carregarCondominios() async {
    try {
      final dados = await _apiService.getCondominios();
      if (mounted) {
        setState(() {
          _condominios = dados;
          if (_condominios.isNotEmpty) {
            _selectedTenantId = _condominios[0]['id'];
          }
        });
      }
    } catch (e) {
      print("Erro ao carregar condomínios: $e");
    }
  }

  Future<void> _selecionarPeriodo() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _dataSelecionada,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue[900],
            colorScheme: ColorScheme.light(primary: Colors.blue[900]!),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _dataSelecionada) {
      setState(() => _dataSelecionada = picked);
    }
  }

  Future<void> _buscarDadosParaExportacao() async {
    if (_selectedTenantId == null) return;
    setState(() => _isLoading = true);
    
    try {
      final dtInicioStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.start);
      final dtFimStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.end);

      final dados = await _apiService.getLeituras(_selectedTenantId!, dtInicio: dtInicioStr, dtFim: dtFimStr);
      
      if (mounted) {
        setState(() {
          _leituras = dados;
          _isLoading = false;
        });

        if (_leituras.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado encontrado neste período.')));
        } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_leituras.length} registros prontos para exportação!'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar dados: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // =========================================================
  // EXPORTAÇÃO EXCEL (CSV com BOM)
  // =========================================================
  void _exportarCSV() {
    if (_leituras.isEmpty) return;
    final nomeCond = _condominios.firstWhere((c) => c['id'] == _selectedTenantId, orElse: () => {'nome': 'Condominio'})['nome'];

    List<List<dynamic>> rows = [];
    rows.add(["Condomínio", "Data", "Bloco", "Unidade", "Medidor", "Leitura", "Status"]);

    for (var row in _leituras) {
      rows.add([
        nomeCond,
        row['data_formatada'] ?? '-',
        row['bloco'] ?? '-',
        row['unidade'] ?? '-',
        row['tipo_medidor'].toString().toUpperCase(),
        row['valor_lido'] ?? '0',
        row['status_leitura'] ?? 'Concluído'
      ]);
    }

    String csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    final bytes = [239, 187, 191] + utf8.encode(csv); // UTF-8 BOM para acentos no Excel
    final blob = html.Blob([Uint8List.fromList(bytes)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Exportacao_CondoLogic_${DateFormat('ddMMyyyy').format(DateTime.now())}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // =========================================================
  // EXPORTAÇÃO XML (Para Integração com Softwares de Gestão)
  // =========================================================
  String _escaparXML(String text) {
    return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
  }

  void _exportarXML() {
    if (_leituras.isEmpty) return;
    final nomeCond = _condominios.firstWhere((c) => c['id'] == _selectedTenantId, orElse: () => {'nome': 'Condominio'})['nome'];

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
      xml.writeln('      <ValorLido>${l['valor_lido']}</ValorLido>');
      xml.writeln('    </Leitura>');
    }

    xml.writeln('  </Registros>');
    xml.writeln('</ExportacaoCondoLogic>');

    final bytes = utf8.encode(xml.toString());
    final blob = html.Blob([Uint8List.fromList(bytes)], 'application/xml');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Exportacao_CondoLogic_${DateFormat('ddMMyyyy').format(DateTime.now())}.xml")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // =========================================================
  // EXPORTAÇÃO PDF
  // =========================================================
  Future<void> _imprimirPDF() async {
    if (_leituras.isEmpty) return;
    final doc = pw.Document();
    final nomeCond = _condominios.firstWhere((c) => c['id'] == _selectedTenantId, orElse: () => {'nome': 'Condominio'})['nome'];
    
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text("Extrato de Leituras para Integração", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
            pw.Text("Condomínio: $nomeCond"),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              data: <List<String>>[
                <String>['Data/Hora', 'Bloco', 'Unidade', 'Medidor', 'Leitura'],
                ..._leituras.map((item) => [
                  item['data_formatada'].toString(),
                  item['bloco'].toString(),
                  item['unidade'].toString(),
                  item['tipo_medidor'].toString().toUpperCase(),
                  item['valor_lido'].toString()
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
        const Text('Extraia as leituras do sistema para importar no seu software de gestão financeira.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: _selectedTenantId,
                    decoration: const InputDecoration(labelText: 'Selecione o Condomínio', border: OutlineInputBorder(), prefixIcon: Icon(Icons.apartment)),
                    items: _condominios.map<DropdownMenuItem<int>>((item) {
                      return DropdownMenuItem<int>(value: item['id'], child: Text(item['nome']));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedTenantId = val),
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
                    _buildExportCard(
                      icon: Icons.table_chart, color: Colors.green, title: "Planilha Excel (CSV)",
                      subtitle: "Para edição manual ou filtros rápidos.", onTap: _exportarCSV
                    ),
                    _buildExportCard(
                      icon: Icons.code, color: Colors.orange, title: "Arquivo XML",
                      subtitle: "Para integração direta com ERPs e contabilidade.", onTap: _exportarXML
                    ),
                    _buildExportCard(
                      icon: Icons.picture_as_pdf, color: Colors.red, title: "Documento PDF",
                      subtitle: "Para impressão e arquivo físico.", onTap: _imprimirPDF
                    ),
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