import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle, TextSpan;
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import '../services/api_service_web.dart';

class ImportacaoScreenWeb extends StatefulWidget {
  const ImportacaoScreenWeb({super.key});

  @override
  State<ImportacaoScreenWeb> createState() => _ImportacaoScreenWebState();
}

class _ImportacaoScreenWebState extends State<ImportacaoScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  
  List<dynamic> _condominios = [];
  int? _selectedTenantId;
  bool _isLoading = false;
  
  PlatformFile? _ficheiroSelecionado;
  Map<String, dynamic>? _resultadoImportacao;

  // VARIÁVEIS PARA A PRÉ-VISUALIZAÇÃO (PREVIEW)
  List<Map<String, dynamic>> _dadosPreparados = [];
  List<List<dynamic>> _dadosPreview = [];
  List<String> _cabecalhoPreview = ['Bloco', 'Unidade', 'Tipo', 'Mês', 'Leitura Ant.', 'Leitura Atual', 'Consumo'];

  @override
  void initState() {
    super.initState();
    _carregarCondominios();
  }

  Future<void> _carregarCondominios() async {
    setState(() => _isLoading = true);
    try {
      final dados = await _apiService.getCondominios();
      if (mounted) {
        setState(() {
          _condominios = dados;
          if (_condominios.isNotEmpty) {
            _selectedTenantId = _condominios[0]['id'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _mostrarMensagem("Erro ao carregar condomínios", isError: true);
      }
    }
  }

  void _mostrarMensagem(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  void _abrirModalAjuda() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 30),
            const SizedBox(width: 10),
            Text("Padrão de Importação (Por Ordem)", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
          ]
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 550,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("O CondoLogic não exige nomes exatos no cabeçalho, mas exige que as informações estejam ESTRITAMENTE nesta ordem nas 15 colunas:", style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                const SizedBox(height: 15),
                _buildRegraItem("Coluna 1: Bloco", "Ex: A"),
                _buildRegraItem("Coluna 2: Unidade", "Ex: 201"),
                _buildRegraItem("Coluna 3: Tipo", "Ex: Água, Água Quente, Gás"),
                _buildRegraItem("Coluna 4: Mês", "Ex: 02/2026"),
                _buildRegraItem("Coluna 5: Data Leitura", "Ex: 2026-02-19 ou 19/02/2026"),
                _buildRegraItem("Coluna 6: Leitura Anterior", "Ex: 1.552"),
                _buildRegraItem("Coluna 7: Leitura Atual", "Ex: 1.553"),
                _buildRegraItem("Coluna 8: Consumo", "Ex: 0.001"),
                _buildRegraItem("Coluna 9: Custo", "Ex: 0"),
                _buildRegraItem("Coluna 10: Custo Adicional", "Ex: 0"),
                _buildRegraItem("Coluna 11: Total", "Ex: 0"),
                _buildRegraItem("Coluna 12: Houve Troca de Medidor?", "Ex: Sim ou Não"),
                _buildRegraItem("Coluna 13: Validade Medidor", "Ex: 31/12/2030 (Opcional)"),
                _buildRegraItem("Coluna 14: Observação", "Ex: Vazamento (Opcional)"),
                _buildRegraItem("Coluna 15: Imagem", "Ex: https://link... (Opcional)"),
              ]
            )
          )
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
            child: const Text("ENTENDI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]
      )
    );
  }

  Widget _buildRegraItem(String titulo, String exemplo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(text: "• $titulo: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
            TextSpan(text: exemplo, style: TextStyle(color: Colors.grey[700])),
          ]
        )
      )
    );
  }

  void _mostrarErroFaltaColunas(int colunasEncontradas) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text("Arquivo Fora do Padrão", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ]
        ),
        content: Text("O ficheiro selecionado não possui as 15 colunas obrigatórias.\n\nSua planilha possui apenas $colunasEncontradas colunas.\n\nPor favor, utilize o formato oficial com a ordem correta das 15 colunas.", style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); 
              _abrirModalAjuda(); 
            }, 
            child: const Text("VER ESTRUTURA PADRÃO", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("OK, VOU CORRIGIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]
      )
    );
  }

  void _baixarPlanilhaPadrao() {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Padrao_CondoLogic'];
    excel.setDefaultSheet('Padrao_CondoLogic');

    sheetObject.appendRow([
      TextCellValue('Bloco'), TextCellValue('Unidade'), TextCellValue('Tipo'),
      TextCellValue('Mês'), TextCellValue('Data Leitura'), TextCellValue('Leitura Anterior'),
      TextCellValue('Leitura Atual'), TextCellValue('Consumo'), TextCellValue('Custo'),
      TextCellValue('Custo Adicional'), TextCellValue('Total'), TextCellValue('Houve Troca de Medidor?'),
      TextCellValue('Validade Medidor'), TextCellValue('Observação'), TextCellValue('Imagem')
    ]);

    sheetObject.appendRow([
      TextCellValue('A'), TextCellValue('201'), TextCellValue('Água'),
      TextCellValue('02/2026'), TextCellValue('2026-02-19'), TextCellValue('140.500'),
      TextCellValue('143.500'), TextCellValue('3.000'), TextCellValue('0'),
      TextCellValue('0'), TextCellValue('0'), TextCellValue('Não'),
      TextCellValue('31/12/2030'), TextCellValue(''), TextCellValue('https://link-da-foto.com')
    ]);

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final blob = html.Blob([Uint8List.fromList(fileBytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Modelo_Nativo_CondoLogic.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<void> _selecionarFicheiro() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );

    if (result != null) {
      setState(() {
        _ficheiroSelecionado = result.files.first;
        _resultadoImportacao = null; 
        _dadosPreparados = []; 
        _dadosPreview = [];
      });
    }
  }

  // Funções Utilitárias para Ler Celulas Dinamicamente
  dynamic _getDynamic(List linha, int index) {
    if (index >= linha.length) return '';
    return linha[index];
  }

  String _safeString(dynamic cell) {
    try {
      if (cell == null) return '';
      String rawVal = cell.value?.toString().trim() ?? '';
      if (cell.value.runtimeType.toString().contains('Date')) {
        var v = cell.value;
        return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
      }
      return rawVal;
    } catch (e) {
      return '';
    }
  }

  double _safeNumber(String v) {
    if (v.isEmpty || v == '-') return 0.0;
    String temp = v.replaceAll('R\$', '').trim();
    if (temp.contains('.') && temp.contains(',')) {
       temp = temp.replaceAll('.', '').replaceAll(',', '.');
    } else {
       temp = temp.replaceAll(',', '.');
    }
    String numLimpo = temp.replaceAll(RegExp(r'[^0-9\.-]'), '');
    return double.tryParse(numLimpo) ?? 0.0;
  }

  // ==============================================================
  // PASSO 1: ANALISA (AGORA PELA ORDEM DAS COLUNAS!)
  // ==============================================================
  Future<void> _analisarArquivo() async {
    if (_selectedTenantId == null || _ficheiroSelecionado == null || _ficheiroSelecionado!.bytes == null) {
      _mostrarMensagem("Selecione um condomínio e um arquivo válido.", isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _dadosPreparados = [];
      _dadosPreview = [];
    });

    try {
      List<Map<String, dynamic>> dadosExtraidos = [];
      final bytes = _ficheiroSelecionado!.bytes!;
      final extensao = _ficheiroSelecionado!.extension?.toLowerCase() ?? '';

      if (extensao == 'xlsx') {
        Excel excel;
        try {
          excel = Excel.decodeBytes(bytes);
        } catch (e) {
          throw Exception("Falha ao abrir a planilha. O arquivo pode estar corrompido ou ser um CSV disfarçado.");
        }

        if (excel.tables.keys.isEmpty) throw Exception("O arquivo Excel não possui abas visíveis.");
        var tabela = excel.tables[excel.tables.keys.first];
        
        if (tabela != null && tabela.rows.isNotEmpty) {
          // Checa apenas a quantidade de colunas (Exige pelo menos 14 colunas. A 15ª imagem é opcional)
          if (tabela.rows[0].length < 14) {
            if (mounted) {
              setState(() => _isLoading = false);
              _mostrarErroFaltaColunas(tabela.rows[0].length);
            }
            return;
          }

          // Lê da linha 1 (pulando o cabeçalho index 0)
          for (int i = 1; i < tabela.rows.length; i++) {
            var linha = tabela.rows[i];
            
            Map<String, dynamic> registo = {
              'bloco': _safeString(_getDynamic(linha, 0)),
              'unidade': _safeString(_getDynamic(linha, 1)),
              'tipo': _safeString(_getDynamic(linha, 2)),
              'mes': _safeString(_getDynamic(linha, 3)),
              'data': _safeString(_getDynamic(linha, 4)),
              'leitura_anterior': _safeNumber(_safeString(_getDynamic(linha, 5))),
              'leitura_atual': _safeNumber(_safeString(_getDynamic(linha, 6))),
              'consumo': _safeNumber(_safeString(_getDynamic(linha, 7))),
              'custo': _safeNumber(_safeString(_getDynamic(linha, 8))),
              'custo_adicional': _safeNumber(_safeString(_getDynamic(linha, 9))),
              'total': _safeNumber(_safeString(_getDynamic(linha, 10))),
              'troca': _safeString(_getDynamic(linha, 11)),
              'validade': _safeString(_getDynamic(linha, 12)),
              'obs': _safeString(_getDynamic(linha, 13)),
              'foto': _safeString(_getDynamic(linha, 14)),
            };

            if (registo['bloco'].toString().isNotEmpty && registo['unidade'].toString().isNotEmpty) {
              dadosExtraidos.add(registo);
            }
          }
        }
      } 
      else if (extensao == 'csv') {
        String csvString;
        try { csvString = utf8.decode(bytes); } catch (e) { csvString = const Latin1Codec().decode(bytes); }

        List<List<dynamic>> csvTable = const CsvToListConverter(fieldDelimiter: ',').convert(csvString);
        if (csvTable.isEmpty || csvTable[0].length <= 1) {
          csvTable = const CsvToListConverter(fieldDelimiter: ';').convert(csvString);
        }

        if (csvTable.isNotEmpty) {
          // Checa quantidade de colunas. O CSV usa length para contar.
          int colCount = csvTable[0].where((c) => c.toString().trim().isNotEmpty).length;
          if (colCount < 14) {
            if (mounted) {
              setState(() => _isLoading = false);
              _mostrarErroFaltaColunas(colCount);
            }
            return;
          }

          for (int i = 1; i < csvTable.length; i++) {
            var linha = csvTable[i];
            
            // Mapagem direta pela Posição do Array (Index)
            Map<String, dynamic> registo = {
              'bloco': _getDynamic(linha, 0).toString().trim(),
              'unidade': _getDynamic(linha, 1).toString().trim(),
              'tipo': _getDynamic(linha, 2).toString().trim(),
              'mes': _getDynamic(linha, 3).toString().trim(),
              'data': _getDynamic(linha, 4).toString().trim(),
              'leitura_anterior': _safeNumber(_getDynamic(linha, 5).toString()),
              'leitura_atual': _safeNumber(_getDynamic(linha, 6).toString()),
              'consumo': _safeNumber(_getDynamic(linha, 7).toString()),
              'custo': _safeNumber(_getDynamic(linha, 8).toString()),
              'custo_adicional': _safeNumber(_getDynamic(linha, 9).toString()),
              'total': _safeNumber(_getDynamic(linha, 10).toString()),
              'troca': _getDynamic(linha, 11).toString().trim(),
              'validade': _getDynamic(linha, 12).toString().trim(),
              'obs': _getDynamic(linha, 13).toString().trim(),
              'foto': _getDynamic(linha, 14).toString().trim(),
            };

            if (registo['bloco'].toString().isNotEmpty && registo['unidade'].toString().isNotEmpty) {
              dadosExtraidos.add(registo);
            }
          }
        }
      }

      if (dadosExtraidos.isEmpty) {
        throw Exception("A planilha parece estar vazia de dados válidos.");
      }

      // Prepara os dados para a grade de pré-visualização
      List<List<dynamic>> prev = dadosExtraidos.map((d) {
        return [
          d['bloco'], d['unidade'], d['tipo'], d['mes'], 
          d['leitura_anterior'], d['leitura_atual'], d['consumo']
        ];
      }).toList();

      setState(() {
        _dadosPreparados = dadosExtraidos;
        _dadosPreview = prev;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarMensagem(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  // ==============================================================
  // PASSO 2: ENVIA OS DADOS DA PRÉ-VISUALIZAÇÃO PARA O BACKEND
  // ==============================================================
  Future<void> _enviarParaBackend() async {
    setState(() => _isLoading = true);
    try {
      final resposta = await _apiService.importarHistorico(_selectedTenantId!, _dadosPreparados);
      
      setState(() {
        _resultadoImportacao = resposta;
        _isLoading = false;
        _dadosPreparados = []; // Limpa a pré-visualização
        _dadosPreview = [];
        _ficheiroSelecionado = null; 
      });

    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarMensagem(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _baixarRelatorioErros() {
    if (_resultadoImportacao == null || _resultadoImportacao!['erros'] == null) return;
    
    List<dynamic> erros = _resultadoImportacao!['erros'];
    String conteudoTexto = "RELATÓRIO DE INCONSISTÊNCIAS - CONDOLOGIC\n\n";
    
    for (var erro in erros) {
      conteudoTexto += "- $erro\n";
    }

    final bytes = utf8.encode(conteudoTexto);
    final blob = html.Blob([bytes], 'text/plain');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Erros_Importacao_${DateTime.now().millisecondsSinceEpoch}.txt")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Integração de Histórico', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
          const SizedBox(height: 5),
          const Text('Importe planilhas geradas pelo DoctorCondo e outras administradoras.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("1. Selecione o Condomínio de Destino", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _selectedTenantId,
                    decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.apartment)),
                    items: _condominios.map<DropdownMenuItem<int>>((item) {
                      return DropdownMenuItem<int>(value: item['id'], child: Text(item['nome']));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedTenantId = val),
                  ),
                  const SizedBox(height: 30),

                  const Text("2. Formato Nativo Requerido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  const Text("O sistema validará os dados de acordo com a ORDEM em que as 15 colunas aparecem.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _baixarPlanilhaPadrao,
                        icon: const Icon(Icons.download, color: Colors.blue),
                        label: const Text('Baixar Planilha Modelo (.xlsx)', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[50], elevation: 0),
                      ),
                      const SizedBox(width: 20),
                      TextButton.icon(
                        onPressed: _abrirModalAjuda,
                        icon: const Icon(Icons.help_outline, color: Colors.orange),
                        label: const Text('Ver estrutura da ordem das colunas', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  const Text("3. Carregar Ficheiro de Dados", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _selecionarFicheiro,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.blue[50],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.upload_file, size: 50, color: Colors.blue[800]),
                          const SizedBox(height: 10),
                          Text(
                            _ficheiroSelecionado != null ? "Arquivo pronto: ${_ficheiroSelecionado!.name}" : "Clique aqui para escolher o arquivo Excel ou CSV",
                            style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _analisarArquivo,
                      icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.search, color: Colors.white, size: 28),
                      label: Text(_isLoading ? 'VERIFICANDO ARQUIVO...' : 'ANALISAR ARQUIVO', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // =========================================================================
          // NOVA SEÇÃO: 4. PRÉ-VISUALIZAÇÃO (Só aparece se tiver dados analisados)
          // =========================================================================
          if (_dadosPreparados.isNotEmpty && _resultadoImportacao == null) ...[
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.orange)),
              child: Padding(
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("4. Pré-visualização e Confirmação", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange[800])),
                        Text("${_dadosPreparados.length} Registos encontrados", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Text("Verifique as primeiras linhas abaixo para garantir que a formatação foi lida corretamente antes de salvar.", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 15),
                    
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.orange[50]),
                          columns: _cabecalhoPreview.map((h) => DataColumn(label: Text(h, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])))).toList(),
                          rows: _dadosPreview.take(10).map((row) {
                            return DataRow(
                              cells: row.map((cell) => DataCell(Text(cell.toString()))).toList()
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, bottom: 20.0),
                      child: Text("* Exibindo apenas as 10 primeiras linhas como amostra.", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _enviarParaBackend,
                        icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save, color: Colors.white, size: 28),
                        label: Text(_isLoading ? 'SALVANDO NO BANCO...' : 'CONFIRMAR E SALVAR IMPORTAÇÃO', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_resultadoImportacao != null) ...[
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue[200]!)),
              child: Padding(
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 30),
                        const SizedBox(width: 10),
                        Text("Auditoria de Importação", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetrica("Lidos", _resultadoImportacao?['resumo']?['total']?.toString() ?? '0', Colors.blue),
                        _buildMetrica("Sucesso", _resultadoImportacao?['resumo']?['sucessos']?.toString() ?? '0', Colors.green),
                        _buildMetrica("Falhas", _resultadoImportacao?['resumo']?['falhas']?.toString() ?? '0', Colors.red),
                        _buildMetrica("Taxa", "${_resultadoImportacao?['resumo']?['percentual'] ?? '0'}%", Colors.orange),
                      ],
                    ),
                    if (((_resultadoImportacao?['erros'] ?? []) as List).isNotEmpty) ...[
                      const SizedBox(height: 25),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Alguns registos falharam (Verifique se os Blocos e Unidades existem no sistema).", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _baixarRelatorioErros,
                              icon: const Icon(Icons.download_for_offline, color: Colors.white),
                              label: const Text('BAIXAR RELATÓRIO DE INCONSISTÊNCIAS (.TXT)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                            ),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildMetrica(String titulo, String valor, MaterialColor cor) {
    return Column(
      children: [
        Text(titulo, style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(valor, style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.bold, color: cor[800])),
      ],
    );
  }
}