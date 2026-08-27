//
// ==========================================>>> checkout_screen_web.dart
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service_web.dart';
import 'main_web_screen.dart';

class CheckoutScreenWeb extends StatefulWidget {
  final Map<String, dynamic> usuarioLogado;
  
  const CheckoutScreenWeb({super.key, required this.usuarioLogado});

  @override
  State<CheckoutScreenWeb> createState() => _CheckoutScreenWebState();
}

class _CheckoutScreenWebState extends State<CheckoutScreenWeb> {
  bool _isLoading = false;
  Map<String, dynamic>? _pixData;
  String? _invoiceUrl;

  Future<void> _gerarCobranca(String formaPagamento, double valor) async {
    setState(() => _isLoading = true);
    
    try {
      // Chama a nossa rota nova do Backend que fala com o Asaas
      final url = Uri.parse('https://condologic-backend.onrender.com/api/pagamentos/checkout');
      final body = jsonEncode({
        'user_id': widget.usuarioLogado['id'].toString(), // O segredo que o Webhook precisa
        'cpf': widget.usuarioLogado['cpf'],
        'nome': widget.usuarioLogado['nome'],
        'email': widget.usuarioLogado['email'],
        'valor': valor,
        'formaPagamento': formaPagamento
      });

      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isLoading = false;
          _invoiceUrl = data['invoiceUrl'];
          _pixData = data['pix'];
        });

        // Se for cartão ou boleto, o Asaas nos dá um link bonito pronto. A gente abre ele numa nova aba.
        if (formaPagamento != 'PIX' && _invoiceUrl != null) {
          final uri = Uri.parse(_invoiceUrl!);
          if (await canLaunchUrl(uri)) {
             await launchUrl(uri, webOnlyWindowName: '_blank');
          }
        }
      } else {
        throw Exception("Erro ao processar cobrança.");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na comunicação com o banco: $e'), backgroundColor: Colors.red));
    }
  }

  // Se o síndico pagou o PIX pelo celular e já quer tentar voltar pro painel
  Future<void> _verificarPagamentoEVoltar() async {
    setState(() => _isLoading = true);
    try {
       // A gente faz um relogin fantasma para puxar os dados atualizados do banco
       final userAtualizado = await ApiServiceWeb().login(widget.usuarioLogado['cpf'], "SENHA_AQUI_OU_FORCA_ATUALIZAR");
       // Na vida real, o ideal seria o backend ter uma rota /auth/me que só pega os dados atualizados
       
       // Para fins práticos de teste, vamos forçar a re-entrada, pois o Webhook já mudou o status no banco
       if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainWebScreen()));
    } catch(e) {
       setState(() => _isLoading = false);
       // Se o status no banco ainda for PENDENTE_PAGAMENTO (nós programamos o F5 no MainWebScreen para travar de novo se não tiver pago)
       if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainWebScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/fundo_web.png', fit: BoxFit.cover)),
          Positioned.fill(child: ColorFiltered(colorFilter: const ColorFilter.mode(Color(0xE60F172A), BlendMode.srcOver), child: const SizedBox())), // Fundo escuro transparente (E6 = 90% opacity)
          
          Center(
            child: Container(
              width: 800, // Aumentei um pouquinho para acomodar os 3 blocos
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30)]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_off, size: 80, color: Colors.orange),
                  const SizedBox(height: 20),
                  Text("SEU PERÍODO DE TESTE TERMINOU", style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                  const SizedBox(height: 10),
                  const Text("Esperamos que o CondoLogic tenha revolucionado sua gestão!\nPara continuar acessando seus dados e utilizando a IA, escolha seu plano abaixo.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
                  
                  const SizedBox(height: 40),

                  if (_isLoading)
                     const Center(child: CircularProgressIndicator())
                  else if (_pixData != null) ...[
                     // SE O SÍNDICO ESCOLHEU PIX, MOSTRA O QR CODE NA TELA
                     const Text("Escaneie o QR Code abaixo com o app do seu banco:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     const SizedBox(height: 20),
                     Image.memory(base64Decode(_pixData!['encodedImage'].split(',').last), width: 250, height: 250),
                     const SizedBox(height: 15),
                     Text("PIX Copia e Cola:", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
                     const SizedBox(height: 5),
                     SelectableText(_pixData!['payload'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                     const SizedBox(height: 30),
                     ElevatedButton.icon(
                        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainWebScreen())), 
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text("JÁ PAGUEI, ACESSAR PAINEL", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20)),
                     )
                  ]
                  else ...[
                     // TELA DE ESCOLHA DE PLANO E PAGAMENTO
                     Row(
                       children: [
                         Expanded(
                           child: _buildPlanoCard("Start", "Até 20 und.", 5.00, "CREDIT_CARD", Icons.credit_card, "Cartão"),
                         ),
                         const SizedBox(width: 15),
                         Expanded(
                           child: _buildPlanoCard("Start", "Até 20 und.", 10.00, "PIX", Icons.qr_code, "PIX"),
                         ),
                         const SizedBox(width: 15),
                         Expanded(
                           child: _buildPlanoCard("Start", "Até 20 und.", 15.00, "BOLETO", Icons.receipt, "Boleto"),
                         )
                       ],
                     ),
                     const SizedBox(height: 20),
                     TextButton.icon(
                        onPressed: () async {
                           await ApiServiceWeb().limparSessao();
                           Navigator.pushReplacementNamed(context, '/'); // Volta pro login caso desista
                        }, 
                        icon: const Icon(Icons.exit_to_app, color: Colors.red),
                        label: const Text("Sair do Sistema", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                     )
                  ]
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPlanoCard(String nomePlano, String subtitulo, double valor, String tipoPgto, IconData icon, String labelBtn) {
    return Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(border: Border.all(color: Colors.blue[200]!, width: 2), borderRadius: BorderRadius.circular(15), color: Colors.blue[50]),
       child: Column(
         children: [
           Text("Plano $nomePlano", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue[900])),
           Text(subtitulo, style: const TextStyle(color: Colors.grey)),
           const SizedBox(height: 15),
           Text("R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}", style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.green)),
           const Text("/mês", style: TextStyle(color: Colors.grey, fontSize: 12)),
           const SizedBox(height: 20),
           ElevatedButton.icon(
              onPressed: () => _gerarCobranca(tipoPgto, valor), 
              icon: Icon(icon, color: Colors.white),
              label: Text(labelBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
           )
         ],
       ),
    );
  }
}