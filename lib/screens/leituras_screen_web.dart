import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LeiturasScreenWeb extends StatefulWidget {
  final int tenantId;
  const LeiturasScreenWeb({Key? key, required this.tenantId}) : super(key: key);

  @override
  _LeiturasScreenWebState createState() => _LeiturasScreenWebState();
}

class _LeiturasScreenWebState extends State<LeiturasScreenWeb> {
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
        Uri.parse('https://condologic-backend.onrender.com/api/leitura/listar?tenant_id=${widget.tenantId}'),
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

  Color _obterCorStatus(String? status) {
    if (status == 'ALERTA') return Colors.red.shade50;
    if (status == 'SUSPEITO') return Colors.orange.shade50;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Auditoria de Fotometria (IA)"),
        backgroundColor: Colors.blueGrey[800],
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _buscarLeituras)],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.blueGrey[100]),
                  columns: const [
                    DataColumn(label: Text('Unidade/Bloco')),
                    DataColumn(label: Text('Anterior')),
                    DataColumn(label: Text('Lido (IA)')),
                    DataColumn(label: Text('Consumo')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Foto')),
                  ],
                  rows: _leituras.map((l) {
                    final status = l['status_leitura'] ?? '';
                    return DataRow(
                      color: MaterialStateProperty.all(_obterCorStatus(status)),
                      cells: [
                        DataCell(Text("${l['unidade_nome']} (${l['bloco_nome']})")),
                        DataCell(Text("${l['leitura_anterior'] ?? '0'}")),
                        DataCell(Text("${l['valor_lido']}", style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text("${l['consumo']} m³")),
                        DataCell(Text(l['observacao'] ?? status, style: TextStyle(color: status == 'ALERTA' ? Colors.red : Colors.black))),
                        DataCell(IconButton(
                          icon: const Icon(Icons.image, color: Colors.blue),
                          onPressed: () => _exibirFoto(l['foto_url']),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }

  void _exibirFoto(String? base64) {
    if (base64 == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Image.memory(base64Decode(base64.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), ''))),
      ),
    );
  }
}