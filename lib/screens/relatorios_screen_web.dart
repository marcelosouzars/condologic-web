import 'dart:convert';
import 'dart:typed_data'; // <--- IMPORTANTE: Adicionado para tratar o arquivo como binário!
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csv/csv.dart';
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
  
  // --- DADOS BRUTOS E FILTRADOS ---
  List<dynamic> _leiturasBrutas = [];
  List<dynamic> _leiturasFiltradas = [];
  
  // --- LISTAS PARA OS DROPDOWNS (CASCATA) ---
  List<dynamic> _condominios = [];
  List<dynamic> _blocos = [];
  List<String> _andares = [];
  List<dynamic> _unidades = [];

  // --- VARIÁVEIS DE SELEÇÃO DOS FILTROS ---
  int? _selectedTenantId;
  Map<String, dynamic>? _selectedBloco;
  String? _selectedAndar;
  Map<String, dynamic>? _selectedUnidade;
  
  // --- FILTRO DE DATA (Padrão: 1º dia do mês atual até hoje) ---
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

  // ==============================================================
  // 1. CARREGAMENTOS EM CASCATA
  // ==============================================================
  
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
          // Reseta os filtros dependentes
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
          
          // Extrai os andares únicos das unidades retornadas
          final andaresUnicos = _unidades.map((u) => u['andar']?.toString() ?? 'Térreo').toSet().toList();
          andaresUnicos.sort(); // Ordena alfabeticamente/numericamente
          _andares = andaresUnicos;
          
          // Reseta a seleção atual
          _selectedAndar = null;
          _selectedUnidade = null;
        });
      }
    } catch (e) {
      print("Erro ao carregar unidades: $e");
    }
  }

  // ==============================================================
  // 2. BUSCA NO BACKEND E FILTRO LOCAL
  // ==============================================================

  Future<void> _buscarRelatorio() async {
    if (_selectedTenantId == null) return;
    setState(() => _isLoading = true);
    
    try {
      // Formata as datas para enviar para a API (AAAA-MM-DD)
      final dtInicioStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.start);
      final dtFimStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.end);

      // Busca tudo do Condomínio no período
      final dados = await _apiService.getLeituras(_selectedTenantId!, dtInicio: dtInicioStr, dtFim: dtFimStr);
      
      if (mounted) {
        setState(() {
          _leiturasBrutas = dados;
          _aplicarFiltrosLocais(); // Filtra na tela por Bloco, Andar e Unidade
          _isLoading = false;
        });

        if (_leiturasFiltradas.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado encontrado para estes filtros.')));
        }
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar dados: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // Mágica do Filtro "Boneca Russa"
  void _aplicarFiltrosLocais() {
    setState(() {
      _leiturasFiltradas = _leiturasBrutas.where((leitura) {
        
        // 1. Filtro de Bloco
        bool passaBloco = _selectedBloco == null || leitura['bloco'].toString() == _selectedBloco!['nome'].toString();
        
        // 2. Filtro de Andar (Verifica se a unidade da leitura pertence ao andar selecionado)
        bool passaAndar = true;
        if (_selectedAndar != null && _selectedUnidade == null) {
          // Pega os nomes de todas as unidades que pertencem ao andar selecionado
          List<String> unidadesDoAndarSelecionado = _unidades
              .where((u) => (u['andar'] ?? 'Térreo') == _selectedAndar)
              .map((u) => u['identificacao'].toString())
              .toList();
          
          passaAndar = unidadesDoAndarSelecionado.contains(leitura['unidade'].toString());
        }

        // 3. Filtro de Unidade Específica
        bool passaUnidade = _selectedUnidade == null || leitura['unidade'].toString() == _selectedUnidade!['identificacao'].toString();

        return passaBloco && passaAndar && passaUnidade;
        
      }).toList();
    });
  }

  // ==============================================================
  // 3. COMPONENTES VISUAIS (SELETORES)
  // ==============================================================

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

  // ==============================================================
  // 4. EXPORTAÇÕES (CSV / PDF)
  // ==============================================================

  void _exportarCSV() {
    if (_leiturasFiltradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não há dados para exportar.')));
      return;
    }

    // Pega o nome do condomínio selecionado
    final nomeCond = _condominios.firstWhere((c) => c['id'] == _selectedTenantId, orElse: () => {'nome': 'Condomínio'})['nome'];

    List<List<dynamic>> rows = [];
    
    // CABEÇALHO COMPLETO PARA O EXCEL (Tabelas Dinâmicas)
    rows.add([
      "Condomínio", 
      "Data", 
      "Bloco", 
      "Unidade", 
      "Medidor", 
      "Leitura anterior", 
      "Leitura atual", 
      "Consumo médio"
    ]);

    for (var row in _leiturasFiltradas) {
      rows.add([
        nomeCond, // Repete o condomínio para Excel conseguir filtrar/agrupar perfeitamente
        row['data_formatada'] ?? '-',
        row['bloco'] ?? '-',
        row['unidade'] ?? '-',
        row['tipo_medidor'].toString().toUpperCase(),
        "0", // Futuramente: Cálculo real da Leitura Anterior vindo do banco
        row['valor_lido'] ?? '0',
        "0"  // Futuramente: Cálculo real do Consumo Médio
      ]);
    }

    // Usando Ponto e Vírgula (;) para o Excel do Brasil organizar as colunas automaticamente
    String csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    
    // Converte a string CSV em lista de bytes
    final bytes = utf8.encode(csv);
    // Adiciona o BOM UTF-8 (Assinatura que avisa o Excel para usar acentos corretamente)
    final bytesComBOM = [239, 187, 191, ...bytes];
    
    // O PULO DO GATO: Converter a lista de inteiros num Uint8List (Arquivo binário)
    final blob = html.Blob([Uint8List.fromList(bytesComBOM)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Relatorio_CondoLogic_${DateFormat('ddMMyyyy').format(DateTime.now())}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Download do Excel iniciado com sucesso!'), backgroundColor: Colors.green[700])
    );
  }

  Future<void> _imprimirPDF() async {
    if (_leiturasFiltradas.isEmpty) return;
    final doc = pw.Document();
    
    final nomeCond = _condominios.firstWhere((c) => c['id'] == _selectedTenantId, orElse: () => {'nome': 'Condomínio'})['nome'];
    final dataGeracao = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final periodoStr = "${DateFormat('dd/MM/yyyy').format(_dataSelecionada.start)} a ${DateFormat('dd/MM/yyyy').format(_dataSelecionada.end)}";

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0, 
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Relatório de Fotometria", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text(nomeCond, style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                ]
              )
            ),
            pw.SizedBox(height: 10),
            pw.Text("Período analisado: $periodoStr", style: pw.TextStyle(fontSize: 12)),
            pw.Text("Filtros aplicados: Bloco: ${_selectedBloco?['nome'] ?? 'Todos'} | Andar: ${_selectedAndar ?? 'Todos'} | Unidade: ${_selectedUnidade?['identificacao'] ?? 'Todas'}", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              data: <List<String>>[
                <String>['Data/Hora', 'Bloco', 'Unidade', 'Medidor', 'Leitura'],
                ..._leiturasFiltradas.map((item) => [
                  item['data_formatada'].toString(),
                  item['bloco'].toString(),
                  item['unidade'].toString(),
                  item['tipo_medidor'].toString().toUpperCase(),
                  item['valor_lido'].toString()
                ])
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Gerado em: $dataGeracao", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                pw.Text("Total de registros exibidos: ${_leiturasFiltradas.length}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))
              ]
            )
          ];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: "Relatorio_CondoLogic");
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

        // --- PAINEL DE FILTROS ---
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // LINHA 1: FILTROS GLOBAIS (CONDOMÍNIO E PERÍODO)
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
                          setState(() => _selectedTenantId = val);
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
                          child: Text(
                            "${DateFormat('dd/MM/yyyy').format(_dataSelecionada.start)} até ${DateFormat('dd/MM/yyyy').format(_dataSelecionada.end)}",
                            style: const TextStyle(fontSize: 16),
                          ),
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

                // LINHA 2: FILTROS ESTRUTURAIS (BLOCO > ANDAR > UNIDADE)
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
                          if (val != null) {
                            _carregarUnidadesEAndares(val['id']);
                          } else {
                            // Se escolheu "TODOS", limpa andar e unidade
                            setState(() { _selectedAndar = null; _selectedUnidade = null; _andares = []; _unidades = []; });
                          }
                          _aplicarFiltrosLocais();
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _selectedAndar,
                        decoration: const InputDecoration(labelText: '4. Andar', border: OutlineInputBorder()),
                        // Desabilita se não tiver bloco selecionado
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
                        items: _selectedBloco == null ? null : [
                          const DropdownMenuItem(value: null, child: Text("TODAS AS UNIDADES", style: TextStyle(fontWeight: FontWeight.bold))),
                          // Filtra as unidades exibidas no dropdown baseando-se no Andar selecionado
                          ..._unidades.where((u) => _selectedAndar == null || (u['andar'] ?? 'Térreo') == _selectedAndar).map(
                            (item) => DropdownMenuItem(value: item, child: Text("Unidade ${item['identificacao']}"))
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedUnidade = val);
                          _aplicarFiltrosLocais();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- BOTÕES DE EXPORTAÇÃO (SÓ APARECEM SE TIVER DADOS) ---
        if (_leiturasFiltradas.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("${_leiturasFiltradas.length} registros encontrados", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _exportarCSV,
                icon: const Icon(Icons.table_view, color: Colors.white),
                label: const Text('BAIXAR EXCEL (CSV)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

        // --- TABELA DE RESULTADOS ---
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _leiturasBrutas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.manage_search, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text("Selecione o período e clique em BUSCAR DADOS", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  )
                )
              : _leiturasFiltradas.isEmpty 
                ? const Center(child: Text("Nenhuma leitura encontrada com os filtros atuais (Bloco/Andar/Unidade).", style: TextStyle(color: Colors.red)))
                : Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: SizedBox(
                      width: double.infinity,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
                          columns: const [
                            DataColumn(label: Text('Data / Hora', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Bloco', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Unidade', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Medidor', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Leitura', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _leiturasFiltradas.map((l) {
                            return DataRow(cells: [
                              DataCell(Text(l['data_formatada'] ?? '-')),
                              DataCell(Text(l['bloco'] ?? '-')),
                              DataCell(Text(l['unidade'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Chip(
                                label: Text(l['tipo_medidor'].toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                backgroundColor: l['tipo_medidor'] == 'gas' ? Colors.orange : Colors.blue[600],
                                padding: EdgeInsets.zero,
                              )),
                              DataCell(Text(l['valor_lido'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green))),
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