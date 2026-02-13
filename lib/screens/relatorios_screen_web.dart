import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csv/csv.dart';
// import 'package:intl/intl.dart'; // (Opcional se formatação já vem do banco)
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html; // Para download Web
import '../services/api_service_web.dart';

class RelatoriosScreenWeb extends StatefulWidget {
  const RelatoriosScreenWeb({super.key});

  @override
  State<RelatoriosScreenWeb> createState() => _RelatoriosScreenWebState();
}

class _RelatoriosScreenWebState extends State<RelatoriosScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  
  List<dynamic> _leituras = [];
  List<dynamic> _condominios = [];
  int? _selectedTenantId;
  
  // Filtros de Data (Padrão: Mês e Ano atuais)
  int _mesSelecionado = DateTime.now().month;
  int _anoSelecionado = DateTime.now().year;
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
            // Opcional: Já buscar ao carregar a tela
            // _buscarRelatorio(); 
          }
        });
      }
    } catch (e) {
      print(e);
    }
  }

  // Busca dados filtrados do Backend
  Future<void> _buscarRelatorio() async {
    if (_selectedTenantId == null) return;
    setState(() => _isLoading = true);
    
    try {
      // Chama a API passando mês e ano
      final dados = await _apiService.getLeituras(_selectedTenantId!, mes: _mesSelecionado, ano: _anoSelecionado);
      setState(() {
        _leituras = dados;
        _isLoading = false;
      });
      
      if (_leituras.isEmpty && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado encontrado para este período.')));
      }

    } catch (e) {
      setState(() => _isLoading = false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  // --- GERAR CSV (EXCEL) ---
  void _exportarCSV() {
    if (_leituras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não há dados na tabela para exportar.')));
      return;
    }

    // Monta as linhas do Excel
    List<List<dynamic>> rows = [];
    // Cabeçalho
    rows.add(["Data", "Bloco", "Unidade", "Medidor", "Leitura Anterior", "Leitura Atual", "Consumo Estimado"]);

    for (var row in _leituras) {
      rows.add([
        row['data_formatada'],
        row['bloco'],
        row['unidade'],
        row['tipo_medidor'],
        "0", // Futuramente: Trazer leitura anterior do banco para cálculo real
        row['valor_lido'],
        "0"  // Futuramente: (Atual - Anterior)
      ]);
    }

    // Converte para texto CSV
    String csv = const ListToCsvConverter().convert(rows);
    
    // --- O PULO DO GATO PARA DOWNLOAD WEB ---
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Leituras_Condo_${_mesSelecionado}_$_anoSelecionado.csv")
      ..click();
    html.Url.revokeObjectUrl(url);

    // --- MENSAGEM INFORMATIVA ---
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.download_done, color: Colors.white),
                SizedBox(width: 10),
                Text('Download Iniciado!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 4),
            Text('Verifique sua pasta padrão (Downloads) ou a barra do navegador.', style: TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating, // Flutua sobre a tela
        width: 450, // Largura fixa para ficar bonito
      )
    );
  }

  // --- GERAR PDF (IMPRESSÃO) ---
  Future<void> _imprimirPDF() async {
    if (_leituras.isEmpty) return;

    final doc = pw.Document();
    
    // Pega o nome do condomínio selecionado
    final nomeCond = _condominios.firstWhere((c) => c['id'] == _selectedTenantId)['nome'];
    final dataGeracao = DateTime.now();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cabeçalho do PDF
              pw.Header(
                level: 0, 
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Relatório de Leituras", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(nomeCond, style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ]
                )
              ),
              
              pw.SizedBox(height: 10),
              pw.Text("Referência: $_mesSelecionado/$_anoSelecionado"),
              pw.Text("Gerado em: ${dataGeracao.day}/${dataGeracao.month}/${dataGeracao.year}"),
              pw.SizedBox(height: 20),

              // Tabela do PDF
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellAlignment: pw.Alignment.centerLeft,
                data: <List<String>>[
                  <String>['Data', 'Unidade', 'Medidor', 'Leitura'], // Cabeçalho Tabela
                  ..._leituras.map((item) => [
                    item['data_formatada'].toString(),
                    "${item['bloco']} - ${item['unidade']}",
                    item['tipo_medidor'].toString().toUpperCase(),
                    item['valor_lido'].toString()
                  ])
                ],
              ),
              
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text("Total de registros: ${_leituras.length}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
              )
            ],
          );
        },
      ),
    );

    // Abre a janela de impressão do navegador
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Relatórios Gerenciais', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 20),

        // --- BARRA DE FILTROS ---
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Dropdown Condomínio
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<int>(
                    value: _selectedTenantId,
                    decoration: const InputDecoration(labelText: 'Condomínio', border: OutlineInputBorder()),
                    items: _condominios.map<DropdownMenuItem<int>>((item) {
                      return DropdownMenuItem<int>(value: item['id'], child: Text(item['nome']));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedTenantId = val),
                  ),
                ),
                
                // Mês
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<int>(
                    value: _mesSelecionado,
                    decoration: const InputDecoration(labelText: 'Mês', border: OutlineInputBorder()),
                    items: List.generate(12, (index) => index + 1).map((m) {
                      return DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')));
                    }).toList(),
                    onChanged: (val) => setState(() => _mesSelecionado = val!),
                  ),
                ),
                
                // Ano
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<int>(
                    value: _anoSelecionado,
                    decoration: const InputDecoration(labelText: 'Ano', border: OutlineInputBorder()),
                    items: [2024, 2025, 2026, 2027].map((a) {
                      return DropdownMenuItem(value: a, child: Text(a.toString()));
                    }).toList(),
                    onChanged: (val) => setState(() => _anoSelecionado = val!),
                  ),
                ),

                // Botão BUSCAR
                ElevatedButton.icon(
                  onPressed: _buscarRelatorio,
                  icon: const Icon(Icons.search, color: Colors.white),
                  label: const Text('FILTRAR DADOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800], 
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- BOTÕES DE AÇÃO (SÓ APARECEM SE TIVER DADOS) ---
        if (_leituras.isNotEmpty)
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _exportarCSV,
                icon: const Icon(Icons.table_view, color: Colors.white),
                label: const Text('BAIXAR EXCEL (CSV)', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], padding: const EdgeInsets.all(16)),
              ),
              const SizedBox(width: 15),
              ElevatedButton.icon(
                onPressed: _imprimirPDF,
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text('IMPRIMIR PDF', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], padding: const EdgeInsets.all(16)),
              ),
            ],
          ),
        
        const SizedBox(height: 20),

        // --- TABELA PREVIEW ---
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _leituras.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.plagiarism_outlined, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      const Text("Selecione os filtros e clique em Filtrar Dados"),
                    ],
                  )
                )
              : Card(
                  child: SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                        columns: const [
                          DataColumn(label: Text('Data')),
                          DataColumn(label: Text('Bloco / Unidade')),
                          DataColumn(label: Text('Medidor')),
                          DataColumn(label: Text('Leitura')),
                        ],
                        rows: _leituras.map((l) {
                          return DataRow(cells: [
                            DataCell(Text(l['data_formatada'])),
                            DataCell(Text('${l['bloco']} - ${l['unidade']}')),
                            DataCell(Chip(
                              label: Text(l['tipo_medidor'].toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                              backgroundColor: l['tipo_medidor'] == 'gas' ? Colors.orange : Colors.blue,
                            )),
                            DataCell(Text(l['valor_lido'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}