import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LeiturasScreen extends StatefulWidget {
  final int tenantId;
  const LeiturasScreen({Key? key, required this.tenantId}) : super(key: key);

  @override
  _LeiturasScreenState createState() => _LeiturasScreenState();
}

class _LeiturasScreenState extends State<LeiturasScreen> {
  List<dynamic> _listaLeituras = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _atualizarLista();
  }

  Future<void> _atualizarLista() async {
    setState(() => _carregando = true);
    try {
      final res = await http.get(
        Uri.parse('https://condologic-backend.onrender.com/api/leitura/listar?tenant_id=${widget.tenantId}'),
      );
      if (res.statusCode == 200) {
        setState(() => _listaLeituras = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint("Erro na web: $e");
    } finally {
      setState(() => _carregando = false);
    }
  }

  // Define a cor de fundo da linha conforme o risco detectado pela IA
  Color _obterCorStatus(String? status) {
    if (status == 'ALERTA') return Colors.red.shade50;
    if (status == 'SUSPEITO') return Colors.orange.shade50;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestão e Auditoria de Fotometria"),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _atualizarLista)],
      ),
      body: _carregando 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.blueGrey[50]),
                  columns: const [
                    DataColumn(label: Text('Unidade/Bloco')),
                    DataColumn(label: Text('Anterior')),
                    DataColumn(label: Text('Lido (IA)')),
                    DataColumn(label: Text('Consumo')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Foto')),
                  ],
                  rows: _listaLeituras.map((leitura) {
                    final status = leitura['status_leitura'] ?? '';
                    return DataRow(
                      color: MaterialStateProperty.all(_obterCorStatus(status)),
                      cells: [
                        DataCell(Text("${leitura['unidade_nome']} (${leitura['bloco_nome']})")),
                        DataCell(Text("${leitura['leitura_anterior'] ?? '0'}")),
                        DataCell(Text("${leitura['valor_lido']}", style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text("${leitura['consumo']} m³")),
                        DataCell(Text(
                          leitura['observacao'] ?? status,
                          style: TextStyle(color: status == 'ALERTA' ? Colors.red : Colors.black),
                        )),
                        DataCell(IconButton(
                          icon: const Icon(Icons.photo, color: Colors.blue),
                          onPressed: () => _exibirFoto(leitura['foto_url']),
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
        title: const Text("Recorte enviado pela IA"),
        content: Image.memory(base64Decode(base64.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), ''))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fechar"))],
      ),
    );
  }
}