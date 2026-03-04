// ==========================================>>> main_web_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MainWebScreen extends StatefulWidget {
  @override
  _MainWebScreenState createState() => _MainWebScreenState();
}

class _MainWebScreenState extends State<MainWebScreen> {
  List<dynamic> unidades = [];
  bool isLoading = true;
  String baseUrl = "https://condologic-backend.onrender.com"; // URL do seu Render

  @override
  void initState() {
    super.initState();
    _fetchDados();
  }

  Future<void> _fetchDados() async {
    try {
      // Busca as unidades e as últimas leituras para conferência do síndico
      final response = await http.get(Uri.parse('$baseUrl/api/dashboard/unidades'));
      if (response.statusCode == 200) {
        setState(() {
          unidades = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar dados web: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("CONDOLOGIC - Painel de Controle (WEB)"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _fetchDados),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Conferência de Leituras", 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
                        columns: [
                          DataColumn(label: Text('Unidade')),
                          DataColumn(label: Text('Bloco')),
                          DataColumn(label: Text('Última Leitura')),
                          DataColumn(label: Text('Consumo (m³)')),
                          DataColumn(label: Text('Custo Est.')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Foto')),
                        ],
                        rows: unidades.map((u) {
                          return DataRow(cells: [
                            DataCell(Text(u['identificacao'] ?? '-')),
                            DataCell(Text(u['bloco_nome'] ?? '-')),
                            DataCell(Text(u['valor_lido']?.toString() ?? 'Pendente')),
                            DataCell(Text(u['consumo']?.toString() ?? '0.0')),
                            DataCell(Text('R\$ ${u['custo_total'] ?? '0.00'}')),
                            DataCell(Icon(
                              u['status_leitura'] == 'Concluído' ? Icons.check_circle : Icons.pending,
                              color: u['status_leitura'] == 'Concluído' ? Colors.green : Colors.orange,
                            )),
                            DataCell(u['foto_url'] != null 
                              ? Icon(Icons.image, color: Colors.blue) 
                              : Icon(Icons.image_not_supported, color: Colors.grey)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}