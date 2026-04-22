// ==========================================>>> dashboard_screen_web.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DashboardScreenWeb extends StatefulWidget {
  final Map<String, dynamic>? usuarioLogado;
  final VoidCallback? onAuditarClique; // Comunicação com a MainWeb

  const DashboardScreenWeb({super.key, this.usuarioLogado, this.onAuditarClique});

  @override
  State<DashboardScreenWeb> createState() => _DashboardScreenWebState();
}

class _DashboardScreenWebState extends State<DashboardScreenWeb> {
  Map<String, dynamic> _resumo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _buscarDados();
  }

  Future<void> _buscarDados() async {
    setState(() => _isLoading = true);
    
    // Extrai o tenant_id do usuário logado ou usa 1 como fallback de segurança
    int tenantId = widget.usuarioLogado?['tenant_id'] ?? 1;

    try {
      final response = await http.get(Uri.parse('https://condologic-backend.onrender.com/api/dashboard/resumo?tenant_id=$tenantId'));
      if (response.statusCode == 200) {
        setState(() => _resumo = jsonDecode(response.body));
      }
    } catch (e) {
      print("Erro dash: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    int erros = _resumo['alertas_pendentes'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Painel de Controle", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blue[900])),
          const SizedBox(height: 30),
          Row(
            children: [
              _cardInformativo("Total de Unidades", _resumo['total_unidades'].toString(), Icons.home, Colors.blue),
              const SizedBox(width: 20),
              _cardInformativo("Leituras do Mês", _resumo['total_lidos'].toString(), Icons.fact_check, Colors.green),
            ],
          ),
          const SizedBox(height: 30),
          // ALERTA DE DISCREPÂNCIA
          if (erros > 0)
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 50),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("ATENÇÃO: $erros DISCREPÂNCIAS DETECTADAS!", style: const TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text("Existem valores fora da média aguardando auditoria."),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: widget.onAuditarClique, // CHAMA A FUNÇÃO DA MAIN!
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(20)),
                    child: const Text("AUDITAR AGORA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardInformativo(String titulo, String valor, IconData icone, Color cor) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Row(
            children: [
              Icon(icone, color: cor, size: 40),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(color: Colors.grey)),
                  Text(valor, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}