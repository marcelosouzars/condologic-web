import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/api_service_web.dart';

class LeiturasScreenWeb extends StatefulWidget {
  const LeiturasScreenWeb({super.key});
  @override
  State<LeiturasScreenWeb> createState() => _LeiturasScreenWebState();
}

class _LeiturasScreenWebState extends State<LeiturasScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  List<dynamic> _leituras = [];
  List<dynamic> _condominios = [];
  bool _isLoading = true;
  int? _selectedTenantId;
  DateTime? _dataInicio;
  DateTime? _dataFim;

  @override
  void initState() {
    super.initState();
    _carregarFiltrosIniciais();
  }

  Future<void> _carregarFiltrosIniciais() async {
    try {
      final condos = await _apiService.getCondominios();
      if (condos.isNotEmpty) {
        setState(() { _condominios = condos; _selectedTenantId = condos[0]['id']; });
        _carregarLeituras();
      } else { setState(() => _isLoading = false); }
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<void> _carregarLeituras() async {
    if (_selectedTenantId == null) return;
    setState(() => _isLoading = true);
    try {
      String? dtIni = _dataInicio != null ? DateFormat('yyyy-MM-dd').format(_dataInicio!) : null;
      String? dtFim = _dataFim != null ? DateFormat('yyyy-MM-dd').format(_dataFim!) : null;
      final res = await _apiService.getLeituras(_selectedTenantId!, dtInicio: dtIni, dtFim: dtFim);
      setState(() { _leituras = res; _isLoading = false; });
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<void> _excluirLeitura(int id) async {
    try { await _apiService.excluirLeitura(id); _carregarLeituras(); } catch(e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'))); }
  }

  Future<void> _selecionarData(bool isInicio) async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
    if (picked != null) setState(() { if (isInicio) _dataInicio = picked; else _dataFim = picked; });
  }

  void _verFoto(String? base64String) {
      if (base64String == null || base64String.length < 50) return;
      showDialog(context: context, builder: (ctx) => Dialog(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.memory(base64Decode(base64String), fit: BoxFit.contain, errorBuilder: (c,o,s)=>const Icon(Icons.broken_image, size: 100)),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FECHAR"))
      ])));
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Histórico de Leituras', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        
        // FILTROS
        Card(child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
            Expanded(flex: 2, child: DropdownButtonFormField<int>(value: _selectedTenantId, items: _condominios.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'], child: Text(c['nome']))).toList(), onChanged: (v){ setState(()=>_selectedTenantId=v); _carregarLeituras(); }, decoration: const InputDecoration(labelText: 'Condomínio', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)))),
            const SizedBox(width: 10),
            Expanded(child: InkWell(onTap: ()=>_selecionarData(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'De', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)), child: Text(_dataInicio != null ? DateFormat('dd/MM/yyyy').format(_dataInicio!) : 'Início')))),
            const SizedBox(width: 5),
            Expanded(child: InkWell(onTap: ()=>_selecionarData(false), child: InputDecorator(decoration: const InputDecoration(labelText: 'Até', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)), child: Text(_dataFim != null ? DateFormat('dd/MM/yyyy').format(_dataFim!) : 'Fim')))),
            const SizedBox(width: 10),
            ElevatedButton(onPressed: _carregarLeituras, style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)), child: const Icon(Icons.search)),
        ]))),
        
        const SizedBox(height: 10),
        
        // LISTA BLINDADA CONTRA TELA CINZA
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _leituras.isEmpty 
            ? const Center(child: Text("Nenhuma leitura encontrada.")) 
            : ListView.builder(itemCount: _leituras.length, itemBuilder: (ctx, i) {
            
            final l = _leituras[i];
            
            // --- BLOCO DE SEGURANÇA (EVITA CRASH) ---
            String titulo = "Unidade Desconhecida";
            String subtitulo = "Sem dados";
            Color corIcone = Colors.grey;
            IconData icone = Icons.help;
            bool temFoto = false;

            try {
                final u = l['unidade_nome'] ?? l['unidade'] ?? '?';
                final b = l['bloco_nome'] ?? l['bloco'] ?? '?';
                final v = l['valor_lido']?.toString() ?? '0';
                final t = l['tipo'] ?? 'agua';
                
                // DATA SEGURA
                String dataStr = l['data_iso'] ?? l['data_formatada'] ?? '';
                if (dataStr.contains('T') || dataStr.contains('-')) {
                   // Formato ISO
                   final dt = DateTime.tryParse(dataStr);
                   if (dt != null) dataStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
                }

                titulo = "$u - $b";
                subtitulo = "Leitura: $v | $dataStr";
                
                if (t == 'agua') { corIcone = Colors.blue; icone = Icons.water_drop; }
                else { corIcone = Colors.orange; icone = Icons.local_fire_department; }
                
                temFoto = (l['foto_url'] != null && l['foto_url'].toString().length > 50);
            } catch (err) {
                print("Erro ao renderizar item $i: $err");
            }
            // ----------------------------------------

            return Card(child: ListTile(
                leading: CircleAvatar(backgroundColor: corIcone.withOpacity(0.2), child: Icon(icone, color: corIcone)),
                title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(subtitulo),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if(temFoto) IconButton(icon: const Icon(Icons.camera_alt, color: Colors.blue), onPressed: ()=>_verFoto(l['foto_url'])),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () {
                        showDialog(context: context, builder: (ctx) => AlertDialog(
                            title: const Text("Excluir?"), content: const Text("Confirmar exclusão?"),
                            actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Não")), TextButton(onPressed: (){Navigator.pop(ctx); _excluirLeitura(l['id']);}, child: const Text("SIM", style: TextStyle(color: Colors.red)))]
                        ));
                    }),
                ]),
            ));
        }))
    ]);
  }
}