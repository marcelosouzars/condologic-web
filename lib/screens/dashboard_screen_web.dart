import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service_web.dart';
import 'auditoria_screen_web.dart';

class DashboardScreenWeb extends StatefulWidget {
  final Map<String, dynamic>? usuarioLogado;
  const DashboardScreenWeb({super.key, this.usuarioLogado});

  @override
  State<DashboardScreenWeb> createState() => _DashboardScreenWebState();
}

class _DashboardScreenWebState extends State<DashboardScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  int _alertasPendentes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregarAlertas();
  }

  Future<void> _carregarAlertas() async {
    if (widget.usuarioLogado == null) return;
    int tenantId = widget.usuarioLogado!['tenant_id'] ?? 1;
    try {
      final dados = await _apiService.getResumoAlertas(tenantId);
      if (mounted) {
        setState(() {
          _alertasPendentes = int.tryParse(dados['total_alertas']?.toString() ?? '0') ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Painel Inicial', 
          style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])
        ),
        const SizedBox(height: 5),
        const Text('Bem-vindo ao centro de controle do seu condomínio.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 30),

        if (_alertasPendentes > 0)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 30),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red, width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: Row(
              children: [
                const Icon(Icons.report_problem, color: Colors.red, size: 50),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Atenção, Síndico!", style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(height: 5),
                      Text("Existem $_alertasPendentes leituras com discrepância aguardando sua conferência."),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AuditoriaScreenWeb(usuarioLogado: widget.usuarioLogado)),
                    ).then((_) => _carregarAlertas()); 
                  },
                  icon: const Icon(Icons.fact_check, color: Colors.white),
                  label: const Text("AUDITAR AGORA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                )
              ],
            ),
          ),

        Row(
          children: [
            _buildCard("Alertas de IA", _alertasPendentes.toString(), Icons.warning_amber, _alertasPendentes > 0 ? Colors.red : Colors.green),
            const SizedBox(width: 20),
            _buildCard("Sistema", "Online", Icons.check_circle_outline, Colors.blue[800]!),
          ],
        ),
      ],
    );
  }

  Widget _buildCard(String titulo, String valor, IconData icone, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(10), 
          border: Border.all(color: Colors.grey[200]!)
        ),
        child: Column(
          children: [
            Icon(icone, color: cor, size: 50),
            const SizedBox(height: 15),
            Text(valor, style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: cor)),
            Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
