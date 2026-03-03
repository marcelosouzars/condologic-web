import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GestaoLeiturasPage extends StatefulWidget {
  final int tenantId;
  const GestaoLeiturasPage({Key? key, required this.tenantId}) : super(key: key);

  @override
  _GestaoLeiturasPageState createState() => _GestaoLeiturasPageState();
}

class _GestaoLeiturasPageState extends State<GestaoLeiturasPage> {
  List<dynamic> _leituras = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _buscarLeituras();
  }

  Future<void> _buscarLeituras() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://seu-backend-no-render.com/api/leitura/listar?tenant_id=${widget.tenantId}'),
      );
      if (response.statusCode == 200) {
        setState(() => _leituras = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Erro ao buscar: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Função que define a cor da linha baseada no perigo
  Color _definirCorLinha(String status) {
    switch (status) {
      case 'ALERTA':
        return Colors.red.shade50; // Vermelho claro para erro crítico
      case 'SUSPEITO':
        return Colors.orange.shade50; // Laranja claro para consumo alto
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Auditoria de Fotometria - CONDOLOGIC"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _buscarLeituras),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
              columns: const [
                DataColumn(label: Text('Unidade/Bloco')),
                DataColumn(label: Text('Leitura Anterior')),
                DataColumn(label: Text('Valor Lido (IA)')),
                DataColumn(label: Text('Consumo')),
                DataColumn(label: Text('Status/Alerta')),
                DataColumn(label: Text('Foto')),
                DataColumn(label: Text('Ações')),
              ],
              rows: _leituras.map((leitura) {
                final String status = leitura['status_leitura'] ?? '';
                final bool temErro = status == 'ALERTA' || status == 'SUSPEITO';

                return DataRow(
                  color: MaterialStateProperty.all(_definirCorLinha(status)),
                  cells: [
                    DataCell(Text("${leitura['unidade_nome']} - ${leitura['bloco_nome']}")),
                    DataCell(Text("${leitura['leitura_anterior'] ?? '0'}")),
                    DataCell(
                      Text(
                        "${leitura['valor_lido']}",
                        style: TextStyle(
                          fontWeight: temErro ? FontWeight.bold : FontWeight.normal,
                          color: temErro ? Colors.red.shade900 : Colors.black,
                        ),
                      ),
                    ),
                    DataCell(Text("${leitura['consumo'] ?? '0'} m³")),
                    DataCell(
                      Row(
                        children: [
                          if (temErro) Icon(Icons.warning_amber_rounded, color: status == 'ALERTA' ? Colors.red : Colors.orange, size: 20),
                          const SizedBox(width: 5),
                          Expanded(child: Text(leitura['observacao'] ?? status, style: TextStyle(fontSize: 12, color: temErro ? Colors.red : Colors.black54))),
                        ],
                      ),
                    ),
                    DataCell(
                      leitura['foto_url'] != null 
                        ? IconButton(
                            icon: const Icon(Icons.image_search, color: Colors.blue),
                            onPressed: () => _verFoto(leitura['foto_url']),
                          )
                        : const Text("-"),
                    ),
                    DataCell(
                      ElevatedButton(
                        onPressed: () => _corrigirLeitura(leitura),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                        child: const Text("Corrigir", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
    );
  }

  void _verFoto(String base64) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(title: const Text("Evidência Fotométrica"), leading: const CloseButton()),
            Image.memory(base64Decode(base64.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), ''))),
          ],
        ),
      ),
    );
  }

  void _corrigirLeitura(dynamic leitura) {
    // Aqui você abriria o modal de edição que já tínhamos nos fontes originais
    print("Abrir correção para ID: ${leitura['id']}");
  }
}