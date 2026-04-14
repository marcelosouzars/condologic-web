import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service_web.dart';

class AuditoriaScreenWeb extends StatefulWidget {
  final Map<String, dynamic>? usuarioLogado;
  const AuditoriaScreenWeb({super.key, required this.usuarioLogado});

  @override
  State<AuditoriaScreenWeb> createState() => _AuditoriaScreenWebState();
}

class _AuditoriaScreenWebState extends State<AuditoriaScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  List<dynamic> _alertas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarListaAuditoria();
  }

  Future<void> _carregarListaAuditoria() async {
    setState(() => _isLoading = true);
    if (widget.usuarioLogado == null) return;
    int tenantId = widget.usuarioLogado!['tenant_id'] ?? 1;

    try {
      final dados = await _apiService.getLeiturasAuditoria(tenantId);
      if (mounted) {
        setState(() {
          _alertas = dados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirModalAuditoria(Map leitura) {
    TextEditingController valorController = TextEditingController(text: leitura['valor_lido'].toString());
    TextEditingController obsController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  Icon(Icons.gavel, color: Colors.blue[900], size: 30),
                  const SizedBox(width: 10),
                  Text("Auditoria - Unidade ${leitura['unidade_nome']}", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                      child: Text("Motivo do Alerta: ${leitura['status_leitura']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),
                    const Text("Valor extraído pela IA:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: valorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(border: OutlineInputBorder(), suffixText: "m³"),
                    ),
                    const SizedBox(height: 20),
                    const Text("Observação da Auditoria (Obrigatório):", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: obsController,
                      maxLines: 2,
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Ex: Confirmada troca de relógio pelo morador."),
                    ),
                    if (isSaving) const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: CircularProgressIndicator()))
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (obsController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A observação é obrigatória!"), backgroundColor: Colors.red));
                      return;
                    }
                    setStateDialog(() => isSaving = true);
                    await _enviarAuditoria(leitura['id'], 'validar', valorController.text, obsController.text);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("VALIDAR IA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (obsController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A observação é obrigatória!"), backgroundColor: Colors.red));
                      return;
                    }
                    setStateDialog(() => isSaving = true);
                    await _enviarAuditoria(leitura['id'], 'corrigir', valorController.text, obsController.text);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                  child: const Text("CORRIGIR MANUAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _enviarAuditoria(int leituraId, String acao, String novoValor, String observacao) async {
    try {
      await _apiService.auditarLeitura(leituraId, acao, novoValor.replaceAll(',', '.'), observacao);
      if (mounted) {
        Navigator.pop(context); // Fecha o modal
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Auditoria registrada com sucesso!"), backgroundColor: Colors.green));
        _carregarListaAuditoria(); // Atualiza a lista na tela
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Auditoria de Leituras", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.red[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _alertas.isEmpty
          ? const Center(child: Text("Excelente! Não há leituras pendentes de auditoria.", style: TextStyle(fontSize: 18, color: Colors.green)))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _alertas.length,
              itemBuilder: (context, index) {
                final l = _alertas[index];
                return Card(
                  color: Colors.red[50],
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.red[200]!)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: const Icon(Icons.warning, color: Colors.red, size: 40),
                    title: Text("Unidade ${l['unidade_nome']} - Medidor: ${l['medidor_tipo'].toString().toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text("Status: ${l['status_leitura']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text("Valor Lido: ${l['valor_lido']} m³   |   Anterior: ${l['leitura_anterior']} m³", style: TextStyle(color: Colors.grey[800])),
                      ],
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _abrirModalAuditoria(l),
                      icon: const Icon(Icons.gavel, color: Colors.white),
                      label: const Text("AUDITAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
