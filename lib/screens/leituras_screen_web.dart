import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LeiturasScreenWeb extends StatefulWidget {
  final int tenantId;
  // Construtor obrigatório para receber o ID do condomínio do main_web_screen
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
      // Endpoint ajustado para seu backend no Render
      final url = Uri.parse('https://condologic-backend.onrender.com/api/leitura/listar?tenant_id=${widget.tenantId}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _leituras = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar auditoria: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Define a cor da linha baseada no status que o Gemini/Backend enviou
  Color _obterCorStatus(String? status) {
    if (status == 'ALERTA') return Colors.red.shade50; // Leitura menor que anterior
    if (status == 'SUSPEITO') return Colors.orange.shade50; // Consumo muito alto
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestão e Auditoria de Fotometria"),
        backgroundColor: const Color(0xFF263238), // blueGrey[900]
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _buscarLeituras,
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Card(
                  elevation: 4,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
                    columns: const [
                      DataColumn(label: Text('Unidade/Bloco', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('L. Anterior', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('L. Atual (IA)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Consumo', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status/Alerta', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Foto', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _leituras.map((leitura) {
                      final status = leitura['status_leitura'] ?? '';
                      final isErro = status == 'ALERTA';

                      return DataRow(
                        color: MaterialStateProperty.all(_obterCorStatus(status)),
                        cells: [
                          DataCell(Text("${leitura['unidade_nome']} (${leitura['bloco_nome']})")),
                          DataCell(Text("${leitura['leitura_anterior'] ?? '0'}")),
                          DataCell(Text(
                            "${leitura['valor_lido']}",
                            style: TextStyle(fontWeight: isErro ? FontWeight.bold : FontWeight.normal),
                          )),
                          DataCell(Text("${leitura['consumo']} m³")),
                          DataCell(
                            Text(
                              leitura['observacao'] ?? status,
                              style: TextStyle(
                                color: isErro ? Colors.red.shade900 : Colors.black,
                                fontWeight: isErro ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.photo_camera, color: Colors.blue),
                              onPressed: () => _mostrarFoto(leitura['foto_url']),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
    );
  }

  void _mostrarFoto(String? base64) {
    if (base64 == null) return;
    
    // Remove o header do base64 se o Flutter não conseguir ler direto
    String limpo = base64.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Evidência de Leitura (IA)"),
        content: SizedBox(
          width: 500,
          child: Image.memory(
            base64Decode(limpo),
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("FECHAR"),
          )
        ],
      ),
    );
  }
}