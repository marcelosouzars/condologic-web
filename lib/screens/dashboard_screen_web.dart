// ==========================================>>> dashboard_screen_web.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 
import 'package:fl_chart/fl_chart.dart'; // PACOTE DE GRÁFICOS
import '../services/api_service_web.dart';

class DashboardScreenWeb extends StatefulWidget {
  final Map<String, dynamic>? usuarioLogado;
  final Map<String, dynamic>? condominioAtivo;
  final VoidCallback? onAuditarClique;

  const DashboardScreenWeb({super.key, this.usuarioLogado, this.condominioAtivo, this.onAuditarClique});

  @override
  State<DashboardScreenWeb> createState() => _DashboardScreenWebState();
}

class _DashboardScreenWebState extends State<DashboardScreenWeb> {
  // Variáveis dos Cards Superiores
  int _totalUnidades = 0;
  int _totalLidos = 0;
  int _qtdAlertasReais = 0;
  
  bool _isLoading = true;
  final ApiServiceWeb _apiService = ApiServiceWeb();

  // =========================================================
  // VARIÁVEIS DOS GRÁFICOS
  // =========================================================
  List<String> _mesesLabels = []; // Labels do Eixo X (Ex: Fev, Mar, Abr)
  Set<String> _tiposDisponiveis = {}; // Quais linhas mostrar (agua_fria, gas...)
  
  // Dados do Gráfico de Linha: Mês -> {Tipo: Consumo Total}
  Map<String, Map<String, double>> _consumoLinha = {}; 
  
  // Dados do Gráfico de Barras (Por Bloco): Bloco -> Consumo Total nos ultimos 3 meses
  Map<String, double> _consumoPorBloco = {};
  
  // Dados do Drill-Down (Por Unidade dentro do Bloco): Bloco -> {Unidade: Consumo}
  Map<String, Map<String, double>> _consumoPorUnidadeDetalhe = {};
  
  // Controle de Interação (Drill-down)
  String? _blocoDetalhadoSelecionado; 

  @override
  void initState() {
    super.initState();
    _buscarDados();
  }

  @override
  void didUpdateWidget(covariant DashboardScreenWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condominioAtivo?['id'] != widget.condominioAtivo?['id']) {
      _buscarDados();
    }
  }

  Future<void> _buscarDados() async {
    if (widget.condominioAtivo == null && widget.usuarioLogado == null) return;
    
    setState(() {
      _isLoading = true;
      _blocoDetalhadoSelecionado = null;
    });
    
    int tenantId = widget.condominioAtivo?['id'] ?? widget.usuarioLogado?['tenant_id'] ?? 1;

    try {
      // 1. CARDS SUPERIORES (LÓGICA RÁPIDA)
      int countUnidades = 0;
      try {
        final blocos = await _apiService.getBlocos(tenantId);
        for (var bloco in blocos) {
          final unidades = await _apiService.getUnidadesPorBloco(bloco['id']);
          countUnidades += (unidades as List).length;
        }
      } catch (_) {}

      // 2. BUSCA DO HISTÓRICO DE 6 MESES PARA OS GRÁFICOS
      DateTime now = DateTime.now();
      DateTime seisMesesAtras = DateTime(now.year, now.month - 5, 1);
      
      String dtInicioStr = DateFormat('yyyy-MM-dd').format(seisMesesAtras);
      String dtFimStr = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));
      
      final leiturasHistorico = await _apiService.getLeituras(tenantId, dtInicio: dtInicioStr, dtFim: dtFimStr);

      // Prepara Labels dos últimos 6 meses e zera os mapas
      _mesesLabels = [];
      _consumoLinha = {};
      DateTime iteradorData = DateTime(seisMesesAtras.year, seisMesesAtras.month, 1);
      for (int i = 0; i < 6; i++) {
        String chaveMesAno = DateFormat('MM/yyyy').format(iteradorData);
        _mesesLabels.add(chaveMesAno);
        _consumoLinha[chaveMesAno] = {'agua_fria': 0, 'agua_quente': 0, 'gas': 0};
        iteradorData = DateTime(iteradorData.year, iteradorData.month + 1, 1);
      }

      int countLidosMesAtual = 0;
      int countAlertasAtual = 0;
      _consumoPorBloco = {};
      _consumoPorUnidadeDetalhe = {};
      _tiposDisponiveis = {};

      String mesAtualLabel = DateFormat('MM/yyyy').format(now);
      DateTime tresMesesAtras = DateTime(now.year, now.month - 2, 1);

      // Processamento das Leituras para abastecer os Gráficos
      for (var leitura in leiturasHistorico) {
        String status = (leitura['status_leitura'] ?? '').toString().toUpperCase();
        String dataStr = (leitura['data_formatada'] ?? leitura['data_leitura'] ?? '').toString();
        String tipoRaw = (leitura['tipo_medidor'] ?? '').toString().toLowerCase();
        double consumo = double.tryParse(leitura['consumo']?.toString() ?? '0') ?? 0;
        String bloco = (leitura['bloco'] ?? leitura['bloco_nome'] ?? 'Sem Bloco').toString();
        String unidade = (leitura['unidade'] ?? leitura['identificacao'] ?? '-').toString();

        // Limpeza do tipo para casar com nossas chaves
        String tipoChave = 'agua_fria';
        if (tipoRaw.contains('quente')) tipoChave = 'agua_quente';
        else if (tipoRaw.contains('gas') || tipoRaw.contains('gás')) tipoChave = 'gas';

        _tiposDisponiveis.add(tipoChave); // Registra que o condomínio tem esse recurso

        DateTime? dtLeitura;
        if (dataStr.contains('/')) {
          final p = dataStr.split(' ')[0].split('/');
          if (p.length == 3) dtLeitura = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        } else if (dataStr.contains('-')) {
          dtLeitura = DateTime.tryParse(dataStr);
        }

        if (dtLeitura != null) {
          String chaveMes = DateFormat('MM/yyyy').format(dtLeitura);
          
          // Agrega pro Gráfico de Linha (6 meses)
          if (_consumoLinha.containsKey(chaveMes)) {
             _consumoLinha[chaveMes]![tipoChave] = (_consumoLinha[chaveMes]![tipoChave]! + consumo);
          }

          // Agrega pro Gráfico de Barras (soma dos últimos 3 meses por bloco)
          if (dtLeitura.isAfter(tresMesesAtras.subtract(const Duration(days: 1)))) {
             _consumoPorBloco[bloco] = (_consumoPorBloco[bloco] ?? 0) + consumo;
             
             // Agrega pro Drill-Down (Soma de consumo por unidade naquele bloco)
             _consumoPorUnidadeDetalhe[bloco] ??= {};
             _consumoPorUnidadeDetalhe[bloco]![unidade] = (_consumoPorUnidadeDetalhe[bloco]![unidade] ?? 0) + consumo;
          }

          // Lógica dos Cards (Apenas mês atual)
          if (chaveMes == mesAtualLabel) {
            countLidosMesAtual++;
            if (status.contains('ALERTA') || status.contains('DISCREP')) {
              countAlertasAtual++;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalUnidades = countUnidades;
          _totalLidos = countLidosMesAtual;
          _qtdAlertasReais = countAlertasAtual;
          _isLoading = false;
        });
      }

    } catch (e) {
      print("Erro fatal no dash: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================
  // COMPONENTE: GRÁFICO DE LINHAS (Evolução 6 Meses)
  // =========================================================
  Widget _buildGraficoLinhas() {
    List<LineChartBarData> linhas = [];

    // Monta a Linha de Água Fria (Azul)
    if (_tiposDisponiveis.contains('agua_fria')) {
      List<FlSpot> spotsFria = [];
      for (int i = 0; i < _mesesLabels.length; i++) {
        spotsFria.add(FlSpot(i.toDouble(), _consumoLinha[_mesesLabels[i]]!['agua_fria']!));
      }
      linhas.add(LineChartBarData(
        spots: spotsFria, isCurved: true, color: Colors.blue, barWidth: 4, 
        dotData: FlDotData(show: true), belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1))
      ));
    }

    // Monta a Linha de Água Quente (Vermelha)
    if (_tiposDisponiveis.contains('agua_quente')) {
      List<FlSpot> spotsQuente = [];
      for (int i = 0; i < _mesesLabels.length; i++) {
        spotsQuente.add(FlSpot(i.toDouble(), _consumoLinha[_mesesLabels[i]]!['agua_quente']!));
      }
      linhas.add(LineChartBarData(
        spots: spotsQuente, isCurved: true, color: Colors.red, barWidth: 4,
        dotData: FlDotData(show: true), belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.1))
      ));
    }

    // Monta a Linha de Gás (Laranja)
    if (_tiposDisponiveis.contains('gas')) {
      List<FlSpot> spotsGas = [];
      for (int i = 0; i < _mesesLabels.length; i++) {
        spotsGas.add(FlSpot(i.toDouble(), _consumoLinha[_mesesLabels[i]]!['gas']!));
      }
      linhas.add(LineChartBarData(
        spots: spotsGas, isCurved: true, color: Colors.orange, barWidth: 4,
        dotData: FlDotData(show: true), belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.1))
      ));
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.only(right: 20, top: 20),
      child: LineChart(
        LineChartData(
          lineBarsData: linhas,
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 50, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[300], strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < _mesesLabels.length) {
                    // Extrai só o mês pra ficar bonito (ex: 02/2026 -> 02)
                    String mesCurto = _mesesLabels[index].split('/')[0];
                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(mesCurto, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)));
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              // tooltipBgColor: Colors.blueGrey.withOpacity(0.8), // Alterado dependendo da versao do fl_chart, se der erro use o abaixo:
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) => LineTooltipItem('${spot.y.toStringAsFixed(1)} m³', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // COMPONENTE: GRÁFICO DE BARRAS (Blocos ou Drill-Down Unidades)
  // =========================================================
  Widget _buildGraficoBarras() {
    List<BarChartGroupData> barras = [];
    List<String> labelsX = [];

    // MODO DRILL-DOWN: Mostra as Top 10 unidades do Bloco clicado
    if (_blocoDetalhadoSelecionado != null) {
      Map<String, double> unidadesDoBloco = _consumoPorUnidadeDetalhe[_blocoDetalhadoSelecionado] ?? {};
      
      // Ordena do maior para o menor e pega os top 10
      var listaOrdenada = unidadesDoBloco.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      var top10 = listaOrdenada.take(10).toList();

      for (int i = 0; i < top10.length; i++) {
        labelsX.add(top10[i].key);
        barras.add(BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(toY: top10[i].value, color: Colors.deepPurple, width: 20, borderRadius: BorderRadius.circular(4))],
        ));
      }
    } 
    // MODO NORMAL: Mostra os Blocos
    else {
      var blocosLista = _consumoPorBloco.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      for (int i = 0; i < blocosLista.length; i++) {
        labelsX.add(blocosLista[i].key);
        barras.add(BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(toY: blocosLista[i].value, color: Colors.teal, width: 30, borderRadius: BorderRadius.circular(4))],
        ));
      }
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.only(top: 20),
      child: BarChart(
        BarChartData(
          barGroups: barras,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < labelsX.length) {
                    // Limpa a string pra caber no gráfico
                    String labelCurto = labelsX[index].replaceAll('Bloco', '').trim();
                    if (labelCurto.length > 5) labelCurto = labelCurto.substring(0, 5); 
                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(labelCurto, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)));
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem('${labelsX[group.x]}\n${rod.toY.toStringAsFixed(1)} m³', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
              },
            ),
            touchCallback: (FlTouchEvent event, barTouchResponse) {
              if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) {
                return;
              }
              // Se clicar num bloco, ativa o drill-down
              if (_blocoDetalhadoSelecionado == null && event.runtimeType.toString().contains('FlTapUpEvent')) {
                int indexClicado = barTouchResponse.spot!.touchedBarGroupIndex;
                if (indexClicado >= 0 && indexClicado < labelsX.length) {
                  setState(() {
                    _blocoDetalhadoSelecionado = labelsX[indexClicado];
                  });
                }
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    String nomeCondominio = widget.condominioAtivo?['nome'] ?? widget.usuarioLogado?['tenant_nome'] ?? widget.usuarioLogado?['nome_condominio'] ?? "Meu Condomínio"; 

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, size: 40, color: Colors.blue[900]),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  "Painel Administrativo: $nomeCondominio",
                  style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // CARDS SUPERIORES
          Row(
            children: [
              _cardInformativo("TOTAL DE UNIDADES", _totalUnidades.toString(), Icons.home_work, Colors.blue),
              const SizedBox(width: 25),
              _cardInformativo("LEITURAS DESTE MÊS", _totalLidos.toString(), Icons.speed, Colors.green),
            ],
          ),

          const SizedBox(height: 30),

          // ALERTA DE DISCREPÂNCIAS
          if (_qtdAlertasReais > 0)
            Container(
              padding: const EdgeInsets.all(30),
              margin: const EdgeInsets.only(bottom: 30),
              decoration: BoxDecoration(
                color: Colors.red[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red, width: 2),
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.report_problem, color: Colors.red, size: 60),
                  const SizedBox(width: 25),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("ATENÇÃO SÍNDICO: $_qtdAlertasReais DISCREPÂNCIAS DETECTADAS!", style: const TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        const Text("O sistema identificou medições com variação suspeita (acima de 40% da última leitura) aguardando sua auditoria.", style: TextStyle(fontSize: 16, color: Colors.black87)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.onAuditarClique, icon: const Icon(Icons.fact_check, color: Colors.white),
                    label: const Text("AUDITAR AGORA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  )
                ],
              ),
            ),

          // =========================================================
          // SESSÃO DOS GRÁFICOS
          // =========================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Gráfico de Linha (Evolução 6 Meses)
              Expanded(
                flex: 5,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Evolução de Consumo (Últimos 6 Meses)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue[900])),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            if (_tiposDisponiveis.contains('agua_fria')) _legendaGrafico("Água Fria", Colors.blue),
                            if (_tiposDisponiveis.contains('agua_quente')) _legendaGrafico("Água Quente", Colors.red),
                            if (_tiposDisponiveis.contains('gas')) _legendaGrafico("Gás", Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildGraficoLinhas(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 25),
              
              // 2. Gráfico de Barras (Ranking Blocos/Unidades)
              Expanded(
                flex: 4,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _blocoDetalhadoSelecionado == null 
                                  ? "Consumo Total por Bloco (3 Meses)" 
                                  : "Top 10 Unidades que mais gastam no $_blocoDetalhadoSelecionado", 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue[900]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_blocoDetalhadoSelecionado != null)
                              TextButton.icon(
                                onPressed: () => setState(() => _blocoDetalhadoSelecionado = null),
                                icon: const Icon(Icons.arrow_back, size: 14),
                                label: const Text("Voltar"),
                              )
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _blocoDetalhadoSelecionado == null 
                            ? "Clique na barra do bloco para ver as unidades detalhadas." 
                            : "Somatória de recursos dos últimos 3 meses.", 
                          style: const TextStyle(color: Colors.grey, fontSize: 12)
                        ),
                        const SizedBox(height: 20),
                        _buildGraficoBarras(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _legendaGrafico(String titulo, Color cor) {
    return Padding(
      padding: const EdgeInsets.only(right: 15.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _cardInformativo(String titulo, String valor, IconData icone, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icone, color: cor, size: 35),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                Text(valor, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue[900])),
              ],
            )
          ],
        ),
      ),
    );
  }
}