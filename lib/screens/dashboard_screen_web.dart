// ==========================================>>> dashboard_screen_web.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service_web.dart'; // IMPORTANTE: Adicionado para usar a mesma inteligência da tela de Leituras

class DashboardScreenWeb extends StatefulWidget {
  final Map<String, dynamic>? usuarioLogado;
  final Map<String, dynamic>? condominioAtivo;
  final VoidCallback? onAuditarClique;

  const DashboardScreenWeb({super.key, this.usuarioLogado, this.condominioAtivo, this.onAuditarClique});

  @override
  State<DashboardScreenWeb> createState() => _DashboardScreenWebState();
}

class _DashboardScreenWebState extends State<DashboardScreenWeb> {
  Map<String, dynamic> _resumo = {};
  int _qtdAlertasReais = 0; // Nova variável para guardar a contagem blindada
  bool _isLoading = true;
  final ApiServiceWeb _apiService = ApiServiceWeb();

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
    
    setState(() => _isLoading = true);
    
    int tenantId = widget.condominioAtivo?['id'] ?? widget.usuarioLogado?['tenant_id'] ?? 1;

    try {
      // 1. Busca os números gerais do dashboard (Unidades, Total Lidos)
      final response = await http.get(Uri.parse('https://condologic-backend.onrender.com/api/dashboard/resumo?tenant_id=$tenantId'));
      if (response.statusCode == 200) {
        _resumo = jsonDecode(response.body);
      }

      // ==============================================================================
      // 2. A MÁGICA: Burlar o resumo furado do backend e contar os alertas na mão!
      // ==============================================================================
      try {
        final alertasBrutos = await _apiService.getLeiturasAuditoria(tenantId);
        int contagemAlertas = 0;
        
        for (var leitura in alertasBrutos) {
          String status = (leitura['status_leitura'] ?? '').toString().toUpperCase();
          // Se tiver "ALERTA" ou "DISCREP", a gente contabiliza como erro pendente
          if (status.contains('ALERTA') || status.contains('DISCREP')) {
            contagemAlertas++;
          }
        }
        _qtdAlertasReais = contagemAlertas;
      } catch (e) {
        print("Erro ao buscar auditoria real: $e");
        // Se a rota falhar, usa o fallback do backend
        _qtdAlertasReais = _resumo['alertas_pendentes'] ?? 0;
      }

    } catch (e) {
      print("Erro dash: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    int totalUnidades = _resumo['total_unidades'] ?? 0;
    int totalLidos = _resumo['total_lidos'] ?? 0;
    
    // Agora usamos a nossa variável blindada em vez de confiar cegamente no backend
    int erros = _qtdAlertasReais;

    String nomeCondominio = widget.condominioAtivo?['nome'] 
        ?? widget.usuarioLogado?['tenant_nome'] 
        ?? widget.usuarioLogado?['nome_condominio']
        ?? "Meu Condomínio"; 

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
          const SizedBox(height: 40),
          
          Row(
            children: [
              _cardInformativo("TOTAL DE UNIDADES", totalUnidades.toString(), Icons.home_work, Colors.blue),
              const SizedBox(width: 25),
              _cardInformativo("LEITURAS DO MÊS", totalLidos.toString(), Icons.speed, Colors.green),
            ],
          ),

          const SizedBox(height: 40),

          // Se _qtdAlertasReais for maior que 0, explode o card vermelho na tela!
          if (erros > 0)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.red, width: 2),
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
                        Text(
                          "ATENÇÃO SÍNDICO: $erros DISCREPÂNCIAS DETECTADAS!",
                          style: const TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          "O sistema identificou medições com variação suspeita (acima de 40% da última leitura) aguardando sua auditoria.",
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.onAuditarClique,
                    icon: const Icon(Icons.fact_check, color: Colors.white),
                    label: const Text("AUDITAR AGORA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 40),
                  const SizedBox(width: 20),
                  Text("Tudo em ordem! Nenhuma discrepância pendente de análise.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.green)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardInformativo(String titulo, String valor, IconData icone, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
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