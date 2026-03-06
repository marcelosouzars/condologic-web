// ==========================================>>> leituras_screen_web.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LeiturasScreenWeb extends StatefulWidget {
  final int tenantId;
  const LeiturasScreenWeb({super.key, required this.tenantId});

  @override
  State<LeiturasScreenWeb> createState() => _LeiturasScreenWebState();
}

class _LeiturasScreenWebState extends State<LeiturasScreenWeb> {
  final String baseUrl = "https://condologic-backend.onrender.com";
  List<dynamic> _condominios = [];
  bool _isLoading = true;
  Map<String, dynamic>? _usuarioLogado;

  @override
  void initState() {
    super.initState();
    _carregarCondominios();
  }

  Future<void> _carregarCondominios() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('usuario_dados');
    if (userString != null) {
      _usuarioLogado = jsonDecode(userString);
    }

    try {
      // Busca condominios baseados no usuario (Se for master, busca todos. Se for sindico, busca o dele)
      int tId = _usuarioLogado?['tenant_id'] ?? widget.tenantId;
      String rota = _usuarioLogado?['nivel_acesso'] == 'master' 
          ? '$baseUrl/api/dashboard/condominios' // Ajuste se tiver uma rota que lista todos os condominios
          : '$baseUrl/api/dashboard/condominios?tenant_id=$tId'; // Fallback

      // Para garantir que funcione com o que já temos, vamos usar a rota de unidades e agrupar
      final response = await http.get(Uri.parse('$baseUrl/api/dashboard/unidades?tenant_id=$tId'));
      
      if (response.statusCode == 200) {
        List<dynamic> dados = json.decode(response.body);
        _agruparDados(dados);
      }
    } catch (e) {
      print("Erro: $e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // Agrupa a lista plana recebida da API na hierarquia: Condominio -> Bloco -> Unidade
  void _agruparDados(List<dynamic> unidadesFlat) {
    Map<String, Map<String, List<dynamic>>> hierarquia = {};

    for (var u in unidadesFlat) {
      String condominio = "Condomínio Base"; // No futuro, puxar u['condominio_nome']
      String bloco = u['bloco_nome'] ?? 'Bloco Único';
      
      if (!hierarquia.containsKey(condominio)) {
        hierarquia[condominio] = {};
      }
      if (!hierarquia[condominio]!.containsKey(bloco)) {
        hierarquia[condominio]![bloco] = [];
      }
      hierarquia[condominio]![bloco]!.add(u);
    }

    // Transforma o Map em uma Lista para o ListView iterar
    List<dynamic> listaPronta = [];
    hierarquia.forEach((nomeCondo, blocos) {
      listaPronta.add({
        'nome_condominio': nomeCondo,
        'blocos': blocos,
      });
    });

    setState(() {
      _condominios = listaPronta;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('GESTÃO DE FOTOMETRIA E AUDITORIA', style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
        const SizedBox(height: 10),
        const Text('Navegue pela estrutura abaixo para consultar as fotos e leituras de cada unidade.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),

        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _condominios.isEmpty 
              ? const Center(child: Text("Nenhuma leitura encontrada para este condomínio."))
              : ListView.builder(
                  itemCount: _condominios.length,
                  itemBuilder: (context, index) {
                    final condo = _condominios[index];
                    Map<String, List<dynamic>> blocos = condo['blocos'];

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        leading: Icon(Icons.apartment, color: Colors.blue[900], size: 30),
                        title: Text(condo['nome_condominio'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        children: blocos.entries.map((blocoEntry) {
                          String nomeBloco = blocoEntry.key;
                          List<dynamic> unidades = blocoEntry.value;

                          return Padding(
                            padding: const EdgeInsets.only(left: 20.0),
                            child: ExpansionTile(
                              leading: const Icon(Icons.domain, color: Colors.orange),
                              title: Text('Bloco/Torre: $nomeBloco', style: const TextStyle(fontWeight: FontWeight.bold)),
                              children: unidades.map((unidade) {
                                
                                bool temLeitura = unidade['status_leitura'] == 'Concluído';
                                String valorLido = unidade['valor_lido']?.toString() ?? 'Sem leitura';
                                String fotoUrl = unidade['foto_url'] ?? '';

                                return ListTile(
                                  contentPadding: const EdgeInsets.only(left: 40, right: 20),
                                  leading: Icon(
                                    temLeitura ? Icons.check_circle : Icons.pending, 
                                    color: temLeitura ? Colors.green : Colors.grey
                                  ),
                                  title: Text('Unidade: ${unidade['identificacao']}'),
                                  subtitle: Text('Leitura: $valorLido m³'),
                                  trailing: fotoUrl.isNotEmpty 
                                    ? OutlinedButton.icon(
                                        onPressed: () {
                                          // Abre modal para ver a foto ampliada
                                          showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: Text('Foto do Medidor - Unidade ${unidade['identificacao']}'),
                                              content: Image.network(fotoUrl), // Se for Base64 tem que usar Image.memory
                                              actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('FECHAR'))],
                                            )
                                          );
                                        }, 
                                        icon: const Icon(Icons.image, color: Colors.blue),
                                        label: const Text("Ver Foto")
                                      )
                                    : const Text("S/ Foto", style: TextStyle(color: Colors.grey)),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}