// ==========================================>>> leituras_screen_web.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service_web.dart';

class LeiturasScreenWeb extends StatefulWidget {
  final int tenantId;
  const LeiturasScreenWeb({super.key, required this.tenantId});

  @override
  State<LeiturasScreenWeb> createState() => _LeiturasScreenWebState();
}

class _LeiturasScreenWebState extends State<LeiturasScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  List<dynamic> _leituras = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarLeituras();
  }

  Future<void> _carregarLeituras() async {
    setState(() => _isLoading = true);
    try {
      final dados = await _apiService.getLeituras(widget.tenantId);
      if (mounted) {
        setState(() {
          _leituras = dados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao carregar leituras"), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('HISTÓRICO DE LEITURAS', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
            ElevatedButton.icon(
              onPressed: _carregarLeituras,
              icon: const Icon(Icons.refresh, color: Colors.blue),
              label: const Text('ATUALIZAR', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[50], elevation: 0),
            ),
          ]
        ),
        const SizedBox(height: 5),
        const Text('Visualize todas as medições processadas no condomínio.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _leituras.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop_outlined, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 10),
                      const Text("Nenhuma leitura registrada ainda.", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _leituras.length,
                  itemBuilder: (context, index) {
                    final l = _leituras[index];
                    
                    // Define a cor da bolinha baseada no status
                    Color corStatus = Colors.green;
                    if (l['status_leitura'].toString().contains('ALERTA')) corStatus = Colors.red;
                    
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[50],
                          radius: 25,
                          child: Icon(Icons.speed, color: Colors.blue[900], size: 28),
                        ),
                        title: Text(
                          "Unidade ${l['unidade'] ?? l['identificacao'] ?? '-'}  |  Medidor: ${l['tipo_medidor'].toString().toUpperCase()}", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text("Data: ${l['data_formatada'] ?? l['data_leitura'] ?? '-'}  |  Bloco: ${l['bloco'] ?? l['bloco_nome'] ?? '-'}"),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: corStatus.withOpacity(0.1), borderRadius: BorderRadius.circular(5), border: Border.all(color: corStatus)),
                                  child: Text(l['status_leitura'] ?? 'Concluída', style: TextStyle(fontSize: 12, color: corStatus, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            )
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("${l['consumo']} m³", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrange)),
                            const SizedBox(height: 4),
                            Text("R\$ ${l['valor_total_faturado'] ?? '0.00'}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    );
                  }
                )
        )
      ],
    );
  }
}