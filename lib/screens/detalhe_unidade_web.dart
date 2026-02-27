import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service_web.dart';

class DetalheUnidadeWeb extends StatefulWidget {
  final Map<String, dynamic> unidade;
  final Map<String, dynamic> condominio;

  const DetalheUnidadeWeb({super.key, required this.unidade, required this.condominio});

  @override
  State<DetalheUnidadeWeb> createState() => _DetalheUnidadeWebState();
}

class _DetalheUnidadeWebState extends State<DetalheUnidadeWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  List<dynamic> _medidores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarMedidores();
  }

  Future<void> _carregarMedidores() async {
    try {
      final dados = await _apiService.getMedidoresUnidade(widget.condominio['id'], widget.unidade['id'] ?? widget.unidade['unidade_id']);
      setState(() {
        _medidores = dados;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Unidade ${widget.unidade['identificacao']} - Visão Geral'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medidores.isEmpty
              ? const Center(child: Text("Nenhum medidor encontrado nesta unidade."))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _medidores.length,
                  itemBuilder: (context, index) {
                    final med = _medidores[index];
                    
                    Color cor = Colors.grey.shade300;
                    if (med['status_cor'] == 'verde') cor = Colors.green;
                    if (med['status_cor'] == 'vermelho') cor = Colors.red;
                    if (med['status_cor'] == 'amarelo') cor = Colors.amber;

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),
                        leading: Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(color: cor, shape: BoxShape.circle, border: Border.all(color: Colors.grey)),
                        ),
                        title: Text('Medidor: ${med['tipo_medidor'].toString().toUpperCase()}', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text('Última leitura computada: ${med['valor_lido'] ?? 'Sem leitura'}', style: const TextStyle(fontSize: 16)),
                            Text('Média de consumo: ${med['media_consumo'] ?? '0'}', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                        trailing: Icon(Icons.speed, color: Colors.blue[800], size: 40),
                      ),
                    );
                  },
                ),
    );
  }
}