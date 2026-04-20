import 'package:flutter/material.dart';
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
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao carregar auditoria.")));
      }
    }
  }

  // ============================================================
  // FUNÇÃO NOVA: ABRIR POPUP PARA CORRIGIR A LEITURA
  // ============================================================
  void _abrirModalCorrecao(Map<String, dynamic> leitura) {
    TextEditingController valorController = TextEditingController(text: leitura['valor_lido']?.toString() ?? '');
    TextEditingController obsController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Corrigir Leitura - ${leitura['unidade']}", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Medidor: ${leitura['tipo_medidor'].toString().toUpperCase()}"),
                    const SizedBox(height: 5),
                    Text("Motivo do Alerta: ${leitura['status_leitura']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    if (leitura['foto_url'] != null && leitura['foto_url'].toString().length > 10)
                      Center(
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
                          child: Image.network(leitura['foto_url'], fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 50)),
                        ),
                      )
                    else 
                      const Center(child: Text("Sem foto disponível")),
                    const SizedBox(height: 20),
                    TextField(
                      controller: valorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Valor Correto da Leitura", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: obsController,
                      decoration: const InputDecoration(labelText: "Justificativa/Observação", border: OutlineInputBorder()),
                    ),
                    if (isSaving) const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: CircularProgressIndicator()))
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: isSaving ? null : () async {
                    if (valorController.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Informe o valor!"), backgroundColor: Colors.red));
                       return;
                    }
                    setStateDialog(() => isSaving = true);
                    try {
                      await _apiService.auditarLeitura(
                        leitura['id'], 
                        'corrigir', 
                        valorController.text.replaceAll(',', '.'), 
                        obsController.text
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        _carregarListaAuditoria(); // Recarrega a lista para sumir o item corrigido
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Corrigido com sucesso!"), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text("SALVAR CORREÇÃO", style: TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Auditoria de Leituras", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _carregarListaAuditoria)
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: Colors.blue[900]))
        : _alertas.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
                  const SizedBox(height: 20),
                  const Text("Nenhuma discrepância pendente!", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              )
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _alertas.length,
              itemBuilder: (context, index) {
                final alerta = _alertas[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 15),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                    title: Text("Unidade: ${alerta['unidade']} - Bloco: ${alerta['bloco']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text("Medidor: ${alerta['tipo_medidor'].toString().toUpperCase()}"),
                        Text("Status: ${alerta['status_leitura']}", style: const TextStyle(color: Colors.red)),
                        Text("Valor Lido pela IA: ${alerta['valor_lido'] ?? 'N/A'}"),
                      ],
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                      label: const Text("CORRIGIR", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                      onPressed: () => _abrirModalCorrecao(alerta),
                    ),
                  ),
                );
              }
            ),
    );
  }
}