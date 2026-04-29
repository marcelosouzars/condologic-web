// ==========================================>>> leituras_screen_web.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service_web.dart';

class LeiturasScreenWeb extends StatefulWidget {
  final int tenantId;
  final bool filtroInicialAuditoria;

  const LeiturasScreenWeb({super.key, required this.tenantId, this.filtroInicialAuditoria = false});

  @override
  State<LeiturasScreenWeb> createState() => _LeiturasScreenWebState();
}

class _LeiturasScreenWebState extends State<LeiturasScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  
  List<dynamic> _leiturasBrutas = [];
  List<dynamic> _leiturasFiltradas = [];
  List<dynamic> _blocos = [];
  List<String> _andares = [];
  List<dynamic> _unidades = [];

  Map<String, dynamic>? _selectedBloco;
  String? _selectedAndar;
  Map<String, dynamic>? _selectedUnidade;
  late DateTimeRange _dataSelecionada;
  bool _isLoading = true;
  bool _mostrarApenasAlertas = false;

  @override
  void initState() {
    super.initState();
    _mostrarApenasAlertas = widget.filtroInicialAuditoria;

    DateTime now = DateTime.now();
    if (_mostrarApenasAlertas) {
      _dataSelecionada = DateTimeRange(
        start: DateTime(2000, 1, 1), 
        end: DateTime(now.year + 1, 12, 31),
      );
    } else {
      _dataSelecionada = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
    }
    
    _inicializarTela();
  }

  Future<void> _inicializarTela() async {
    await _carregarBlocos();
    await _buscarDados();
  }

  String _formatarMedicao(dynamic valor) {
    if (valor == null) return '0,000';
    double v = double.tryParse(valor.toString()) ?? 0.0;
    return v.toStringAsFixed(3).replaceAll('.', ',');
  }

  // =========================================================================
  // FUNÇÕES DE ORDENAÇÃO INTELIGENTE (ALFANUMÉRICA)
  // =========================================================================
  
  // Garante que "Apto 2" venha antes de "Apto 10"
  String _padNumbers(String input) {
    return input.replaceAllMapped(RegExp(r'\d+'), (Match m) => m[0]!.padLeft(10, '0'));
  }

  // Ordenação específica para andares (Térreo primeiro, depois numérico)
  int _compararAndares(String a, String b) {
    String valA = a.toLowerCase().trim();
    String valB = b.toLowerCase().trim();
    
    if (valA == valB) return 0;
    if (valA.contains('térreo')) return -1;
    if (valB.contains('térreo')) return 1;

    // Extrai apenas os números para comparar como Inteiro
    final numA = int.tryParse(valA.replaceAll(RegExp(r'[^0-9]'), ''));
    final numB = int.tryParse(valB.replaceAll(RegExp(r'[^0-9]'), ''));

    if (numA != null && numB != null) {
      return numA.compareTo(numB);
    }
    return valA.compareTo(valB);
  }

  Widget _buildLabelAndField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  Future<void> _carregarBlocos() async {
    try {
      final dados = await _apiService.getBlocos(widget.tenantId);
      
      // Ordena Blocos Alfabeticamente
      dados.sort((a, b) => a['nome'].toString().toLowerCase().compareTo(b['nome'].toString().toLowerCase()));

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
      
      // Ordena Unidades Numericamente (Apto 2 < Apto 10)
      dados.sort((a, b) => _padNumbers(a['identificacao'].toString()).compareTo(_padNumbers(b['identificacao'].toString())));

      if (mounted) {
        setState(() {
          _unidades = dados;
          final andaresUnicos = _unidades.map((u) => u['andar']?.toString() ?? 'Térreo').toSet().toList();
          
          // Ordena Andares usando nossa regra inteligente
          andaresUnicos.sort((a, b) => _compararAndares(a, b));
          
          _andares = andaresUnicos;
          _selectedAndar = null;
          _selectedUnidade = null;
        });
      }
    } catch (e) {
      print("Erro ao carregar unidades: $e");
    }
  }

  Future<void> _buscarDados() async {
    setState(() => _isLoading = true);
    try {
      List<dynamic> dados = [];
      final dtInicioStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.start);
      final dtFimStr = DateFormat('yyyy-MM-dd').format(_dataSelecionada.end);
      
      dados = await _apiService.getLeituras(widget.tenantId, dtInicio: dtInicioStr, dtFim: dtFimStr, blocoId: _selectedBloco?['id']);
      
      if (dados.isEmpty && _selectedBloco != null) {
        dados = await _apiService.getLeituras(widget.tenantId, blocoId: _selectedBloco?['id']);
      }
      
      if (mounted) {
        setState(() {
          _leiturasBrutas = dados;
          _aplicarFiltrosLocais();
          _isLoading = false;
        });
      }
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
        if (!_mostrarApenasAlertas) {
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
        }

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

        bool passaStatus = true;
        if (_mostrarApenasAlertas) {
          String status = (leitura['status_leitura'] ?? '').toString().toUpperCase();
          passaStatus = status.contains('ALERTA') || status.contains('DISCREP');
        }

        return passaData && passaBloco && passaAndar && passaUnidade && passaStatus;
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
                  const Text("Defina a data inicial e final para visualizar as leituras:", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(context: context, initialDate: inicioTemp, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
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
                            DateTime? picked = await showDatePicker(context: context, initialDate: fimTemp, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A Data Final não pode ser anterior à Inicial."), backgroundColor: Colors.red));
                      return;
                    }
                    setState(() {
                      _dataSelecionada = DateTimeRange(start: inicioTemp, end: fimTemp);
                    });
                    Navigator.pop(ctx);
                    _buscarDados();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                  child: const Text("CONFIRMAR E BUSCAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // MODAL: INCLUSÃO MANUAL DE LEITURA (COM ORDENAÇÃO CORRIGIDA)
  // =========================================================================
  void _abrirModalInclusaoManual() {
    Map<String, dynamic>? blocoSel;
    String? andarSel;
    Map<String, dynamic>? unidadeSel;
    Map<String, dynamic>? medidorSel;

    List<String> andaresModal = [];
    List<dynamic> unidadesModal = [];
    List<dynamic> medidoresModal = [];

    TextEditingController valorController = TextEditingController();
    TextEditingController obsController = TextEditingController();
    
    DateTime agora = DateTime.now();
    String mesReferencia = "${agora.month.toString().padLeft(2, '0')}/${agora.year}";

    bool isSaving = false;
    bool isLoadingMedidores = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            
            Future<void> carregarAndaresEUnidadesModal(int blocoId) async {
              try {
                final dados = await _apiService.getUnidadesPorBloco(blocoId);
                
                // ORDENAÇÃO: Unidades (Apto 2 antes do 10)
                dados.sort((a, b) => _padNumbers(a['identificacao'].toString()).compareTo(_padNumbers(b['identificacao'].toString())));

                final andaresUnicos = dados.map((u) => u['andar']?.toString() ?? 'Térreo').toSet().toList();
                
                // ORDENAÇÃO: Andares (Térreo, 1, 2, 3...)
                andaresUnicos.sort((a, b) => _compararAndares(a, b));

                setStateModal(() {
                  unidadesModal = dados;
                  andaresModal = andaresUnicos;
                  andarSel = null;
                  unidadeSel = null;
                  medidorSel = null;
                  medidoresModal = [];
                });
              } catch (e) {
                print("Erro ao carregar $e");
              }
            }

            Future<void> carregarMedidoresModal(int unidadeId) async {
              setStateModal(() => isLoadingMedidores = true);
              try {
                final dados = await _apiService.getMedidoresUnidade(widget.tenantId, unidadeId);
                
                // Ordenação Alfabética dos Medidores
                dados.sort((a, b) => (a['tipo_medidor'] ?? '').toString().compareTo((b['tipo_medidor'] ?? '').toString()));

                setStateModal(() {
                  medidoresModal = dados;
                  medidorSel = null;
                  isLoadingMedidores = false;
                });
              } catch (e) {
                setStateModal(() => isLoadingMedidores = false);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  Icon(Icons.add_task, color: Colors.green[800]),
                  const SizedBox(width: 10),
                  Text("Inclusão Manual de Leitura", style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 10),
                            Expanded(child: Text("A leitura inserida por aqui será automaticamente marcada como VALIDADA e entrará para o cálculo.", style: TextStyle(fontSize: 12, color: Colors.black87))),
                          ],
                        ),
                      ),
                      
                      Text("Mês de Referência: $mesReferencia", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),

                      DropdownButtonFormField<Map<String, dynamic>?>(
                        value: blocoSel,
                        decoration: const InputDecoration(labelText: '1. Selecione o Bloco', border: OutlineInputBorder(), isDense: true),
                        items: _blocos.map<DropdownMenuItem<Map<String, dynamic>?>>((item) => DropdownMenuItem<Map<String, dynamic>?>(value: item, child: Text(item['nome']))).toList(),
                        onChanged: (val) {
                          setStateModal(() { blocoSel = val; });
                          if (val != null) carregarAndaresEUnidadesModal(val['id']);
                        },
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<String?>(
                        value: andarSel,
                        decoration: const InputDecoration(labelText: '2. Selecione o Andar', border: OutlineInputBorder(), isDense: true),
                        items: blocoSel == null ? null : andaresModal.map<DropdownMenuItem<String?>>((andar) => DropdownMenuItem<String?>(value: andar, child: Text(andar))).toList(),
                        onChanged: (val) {
                          setStateModal(() { andarSel = val; unidadeSel = null; medidorSel = null; medidoresModal = []; });
                        },
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<Map<String, dynamic>?>(
                        value: unidadeSel,
                        decoration: const InputDecoration(labelText: '3. Selecione a Unidade', border: OutlineInputBorder(), isDense: true),
                        items: andarSel == null ? null : unidadesModal.where((u) => (u['andar']?.toString() ?? 'Térreo') == andarSel).map<DropdownMenuItem<Map<String, dynamic>?>>(
                          (item) => DropdownMenuItem<Map<String, dynamic>?>(value: item, child: Text("Unidade ${item['identificacao']}"))
                        ).toList(),
                        onChanged: (val) {
                          setStateModal(() => unidadeSel = val);
                          if (val != null) carregarMedidoresModal(val['id']);
                        },
                      ),
                      const SizedBox(height: 10),

                      if (isLoadingMedidores)
                        const Padding(padding: EdgeInsets.all(10), child: Center(child: CircularProgressIndicator()))
                      else
                        DropdownButtonFormField<Map<String, dynamic>?>(
                          value: medidorSel,
                          decoration: const InputDecoration(labelText: '4. Selecione o Medidor', border: OutlineInputBorder(), isDense: true),
                          items: unidadeSel == null ? null : medidoresModal.map<DropdownMenuItem<Map<String, dynamic>?>>((item) => DropdownMenuItem<Map<String, dynamic>?>(value: item, child: Text(item['tipo_medidor'].toString().toUpperCase()))).toList(),
                          onChanged: (val) => setStateModal(() => medidorSel = val),
                        ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: valorController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: "5. Valor Lido (M³)", 
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.speed),
                          hintText: "Ex: 15.400"
                        ),
                      ),
                      const SizedBox(height: 15),

                      TextField(
                        controller: obsController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: "6. Justificativa / Observação (Opcional)", 
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.comment),
                        ),
                      ),
                      
                      if (isSaving) const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: CircularProgressIndicator()))
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                  icon: const Icon(Icons.save, color: Colors.white),
                  onPressed: isSaving ? null : () async {
                    if (medidorSel == null || valorController.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione o medidor e informe o valor!"), backgroundColor: Colors.red));
                       return;
                    }
                    setStateModal(() => isSaving = true);
                    try {
                      String valorFinal = valorController.text.replaceAll(',', '.');
                      await _apiService.incluirLeituraManual({
                        'tenant_id': widget.tenantId,
                        'medidor_id': medidorSel!['medidor_id'], 
                        'valor_lido': valorFinal,
                        'mes_referencia': mesReferencia,
                        'observacao': obsController.text.isEmpty ? 'Inclusão manual via Web' : obsController.text
                      });
                      
                      if (mounted) {
                        Navigator.pop(ctx);
                        _buscarDados(); 
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leitura inserida com sucesso!"), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setStateModal(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
                    }
                  },
                  label: const Text("SALVAR LEITURA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      }
    );
  }

  // =========================================================================
  // MODAL DE EDIÇÃO
  // =========================================================================
  void _abrirModalEdicao(Map<String, dynamic> leitura) {
    TextEditingController valorController = TextEditingController(text: _formatarMedicao(leitura['valor_lido']).replaceAll(',', '.'));
    TextEditingController obsController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.blue[900]),
                  const SizedBox(width: 10),
                  Text("Corrigir Leitura - Apto ${leitura['unidade'] ?? leitura['identificacao'] ?? '-'}", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Medidor: ${(leitura['tipo_medidor'] ?? '').toString().toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(height: 5),
                          Text("Status Atual: ${leitura['status_leitura']}", style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: valorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Novo Valor Correto (m³)", 
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.speed),
                        hintText: "Ex: 12.345"
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: obsController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Justificativa da Alteração", 
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.comment),
                        hintText: "Ex: Erro de leitura da IA"
                      ),
                    ),
                    if (isSaving) const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: CircularProgressIndicator()))
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.check, color: Colors.white),
                  onPressed: isSaving ? null : () async {
                    if (valorController.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Informe o valor!"), backgroundColor: Colors.red));
                       return;
                    }
                    if (obsController.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Informe a justificativa!"), backgroundColor: Colors.red));
                       return;
                    }

                    setStateDialog(() => isSaving = true);
                    try {
                      String valorFinal = valorController.text.replaceAll(',', '.');
                      
                      await _apiService.auditarLeitura(
                        leitura['id'], 
                        'corrigir', 
                        valorFinal, 
                        obsController.text
                      );
                      
                      if (mounted) {
                        Navigator.pop(ctx);
                        _buscarDados(); 
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leitura alterada e auditada com sucesso!"), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red));
                    }
                  },
                  label: const Text("SALVAR ALTERAÇÃO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leituras Registradas', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                const SizedBox(height: 5),
                const Text('Visualize e filtre o histórico de medições do condomínio.', style: TextStyle(color: Colors.grey)),
              ],
            ),
            Row(
              children: [
                Row(
                  children: [
                    Switch(
                      value: _mostrarApenasAlertas,
                      activeColor: Colors.red,
                      onChanged: (val) {
                        setState(() {
                          _mostrarApenasAlertas = val;
                        });
                        _buscarDados(); 
                      },
                    ),
                    const Text("Somente Discrepâncias", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 20),
                
                ElevatedButton.icon(
                  onPressed: _abrirModalInclusaoManual,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("INCLUIR LEITURA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                ),
                const SizedBox(width: 20),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
                  child: Text("Total Listado: ${_leiturasFiltradas.length}", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
        
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildLabelAndField(
                        '1. Período de Análise',
                        InkWell(
                          onTap: _mostrarApenasAlertas ? null : _selecionarPeriodo,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(), 
                              prefixIcon: Icon(Icons.calendar_month, color: _mostrarApenasAlertas ? Colors.grey : Colors.black87), 
                              isDense: true
                            ),
                            child: Text(
                              _mostrarApenasAlertas ? "Todo o período (Alertas Pendentes)" : "${DateFormat('dd/MM/yyyy').format(_dataSelecionada.start)} até ${DateFormat('dd/MM/yyyy').format(_dataSelecionada.end)}", 
                              style: TextStyle(fontSize: 15, color: _mostrarApenasAlertas ? Colors.grey : Colors.black87)
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    
                    Expanded(
                      flex: 2,
                      child: _buildLabelAndField(
                        '2. Bloco / Torre',
                        DropdownButtonFormField<Map<String, dynamic>?>(
                          value: _selectedBloco,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          hint: const Text("TODOS OS BLOCOS"),
                          items: [
                            const DropdownMenuItem<Map<String, dynamic>?>(value: null, child: Text("TODOS OS BLOCOS", style: TextStyle(fontWeight: FontWeight.bold))),
                            ..._blocos.map<DropdownMenuItem<Map<String, dynamic>?>>((item) => DropdownMenuItem<Map<String, dynamic>?>(value: item, child: Text(item['nome']))).toList(),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedBloco = val);
                            if (val != null) _carregarUnidadesEAndares(val['id']);
                            else setState(() { _selectedAndar = null; _selectedUnidade = null; _andares = []; _unidades = []; });
                            _aplicarFiltrosLocais();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    
                    Expanded(
                      flex: 2,
                      child: _buildLabelAndField(
                        '3. Andar',
                        DropdownButtonFormField<String?>(
                          value: _selectedAndar,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          hint: Text(
                            _selectedBloco == null ? "Indisponível (Bloco não selecionado)" : "TODOS OS ANDARES", 
                            style: TextStyle(color: _selectedBloco == null ? Colors.red[300] : Colors.black87)
                          ),
                          disabledHint: const Text("Indisponível (Bloco não selecionado)", style: TextStyle(color: Colors.grey)),
                          items: _selectedBloco == null ? null : [
                            const DropdownMenuItem<String?>(value: null, child: Text("TODOS OS ANDARES", style: TextStyle(fontWeight: FontWeight.bold))),
                            ..._andares.map<DropdownMenuItem<String?>>((andar) => DropdownMenuItem<String?>(value: andar, child: Text(andar))).toList(),
                          ],
                          onChanged: (val) {
                            setState(() { _selectedAndar = val; _selectedUnidade = null; });
                            _aplicarFiltrosLocais();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),

                    Expanded(
                      flex: 2,
                      child: _buildLabelAndField(
                        '4. Unidade',
                        DropdownButtonFormField<Map<String, dynamic>?>(
                          value: _selectedUnidade,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          hint: Text(
                            _selectedAndar == null ? "Indisponível (Andar não selecionado)" : "TODAS AS UNIDADES",
                            style: TextStyle(color: _selectedAndar == null ? Colors.red[300] : Colors.black87)
                          ),
                          disabledHint: const Text("Indisponível (Andar não selecionado)", style: TextStyle(color: Colors.grey)),
                          items: (_selectedBloco == null || _selectedAndar == null) ? null : [
                            const DropdownMenuItem<Map<String, dynamic>?>(value: null, child: Text("TODAS AS UNIDADES", style: TextStyle(fontWeight: FontWeight.bold))),
                            ..._unidades.where((u) => _selectedAndar == null || (u['andar']?.toString() ?? 'Térreo') == _selectedAndar).map<DropdownMenuItem<Map<String, dynamic>?>>(
                              (item) => DropdownMenuItem<Map<String, dynamic>?>(value: item, child: Text("Unidade ${item['identificacao']}"))
                            ).toList(),
                          ],
                          onChanged: (_selectedBloco == null || _selectedAndar == null) ? null : (val) {
                            setState(() => _selectedUnidade = val);
                            _aplicarFiltrosLocais();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),

                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _buscarDados,
                        icon: const Icon(Icons.search, color: Colors.white),
                        label: const Text('BUSCAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], padding: const EdgeInsets.symmetric(horizontal: 24)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),

        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _leiturasBrutas.isEmpty 
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.event_busy, size: 80, color: Colors.grey[300]), const SizedBox(height: 10), Text("Nenhuma leitura encontrada.", style: TextStyle(color: Colors.red[600], fontSize: 16, fontWeight: FontWeight.bold))]))
              : _leiturasFiltradas.isEmpty 
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.filter_alt_off, size: 80, color: Colors.grey[300]), const SizedBox(height: 10), const Text("Nenhuma leitura corresponde aos filtros selecionados.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]))
                : Card( 
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical, 
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal, 
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
                            columnSpacing: 30, 
                            columns: const [
                              DataColumn(label: Text('Data / Hora', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Bloco / Unidade', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Medidor', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Leitura Ant.', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Leitura Atual', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Consumo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                              DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                            ],
                            rows: _leiturasFiltradas.map((l) {
                              Color? corFundo = Colors.blue[600];
                              String tipoStr = l['tipo_medidor']?.toString().toLowerCase() ?? '';
                              if (tipoStr.contains('quente')) corFundo = Colors.red[600];
                              else if (tipoStr.contains('gas') || tipoStr.contains('gás')) corFundo = Colors.orange;

                              Color statusColor = Colors.green;
                              String statusTexto = (l['status_leitura'] ?? 'Concluída').toString().toUpperCase();
                              if (statusTexto.contains('ALERTA') || statusTexto.contains('DISCREP')) statusColor = Colors.red;
                              else if (statusTexto.contains('CORRIGIDA')) statusColor = Colors.purple;
                              else if (statusTexto.contains('PENDENTE')) statusColor = Colors.orange;
                              return DataRow(
                                color: statusTexto.contains('ALERTA') || statusTexto.contains('DISCREP') 
                                    ? MaterialStateProperty.all(Colors.red[50]) 
                                    : null,
                                cells: [
                                  DataCell(Text(l['data_formatada'] ?? l['data_leitura'] ?? '-', style: const TextStyle(fontSize: 13))),
                                  DataCell(Text("${l['bloco'] ?? l['bloco_nome'] ?? '-'} - ${l['unidade'] ?? l['identificacao'] ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                  DataCell(Chip(label: Text((l['tipo_medidor'] ?? 'Desc.').toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: corFundo, padding: EdgeInsets.zero)),
                                  DataCell(Text(_formatarMedicao(l['leitura_anterior']), style: const TextStyle(fontSize: 13))),
                                  DataCell(Text(_formatarMedicao(l['valor_lido']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                  DataCell(Text('${_formatarMedicao(l['consumo'])} m³', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13))),
                                  DataCell(Text(statusTexto, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 12))),
                                  DataCell(
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                                      label: const Text('EDITAR', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[700],
                                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      onPressed: () => _abrirModalEdicao(l),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}