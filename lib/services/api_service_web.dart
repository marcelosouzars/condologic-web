import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiServiceWeb {
  // --- ATENÇÃO: COLOQUE AQUI SUA URL EXATA DO RENDER ---
  static const String baseUrl = 'https://condologic-backend.onrender.com/api'; 
  
  // ... (O resto do código continua igual ao arquivo das 20:00)
  
  // --- LOGIN ---
  Future<Map<String, dynamic>> login(String cpf, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      final cpfLimpo = cpf.replaceAll(RegExp(r'[^0-9]'), '');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cpf': cpfLimpo, 'senha': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro desconhecido');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // ... (Mantenha todas as outras funções: getCondominios, criarUsuario, etc.)
  // O importante é que todas usem a variável 'baseUrl' que alteramos acima.
  
  // --- CONDOMÍNIOS ---
  Future<List<dynamic>> getCondominios({int? usuarioId, String? nivel}) async {
    // Ajustei para aceitar filtros se necessário, igual fizemos antes
    String query = '$baseUrl/admin/condominios';
    if (usuarioId != null) query += '?usuario_id=$usuarioId&nivel=$nivel';
    
    final response = await http.get(Uri.parse(query));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao carregar condomínios');
  }
  
  Future<void> criarCondominio(Map<String, dynamic> dados) async {
    final response = await http.post(Uri.parse('$baseUrl/admin/condominio'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
    if (response.statusCode != 201) throw Exception('Erro ao criar: ${response.body}');
  }

  Future<void> editarCondominio(int id, Map<String, dynamic> dados) async {
    final response = await http.put(Uri.parse('$baseUrl/admin/condominio/$id'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
    if (response.statusCode != 200) throw Exception('Erro ao editar');
  }

  Future<void> excluirCondominio(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/condominio/$id'));
    if (response.statusCode != 200) throw Exception('Erro ao excluir');
  }

  // --- EQUIPE E VÍNCULOS ---
  Future<List<dynamic>> buscarUsuarios(String termo) async {
    final response = await http.get(Uri.parse('$baseUrl/admin/usuarios/buscar?termo=$termo'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getEquipeCondominio(int tenantId) async {
    final response = await http.get(Uri.parse('$baseUrl/admin/condominio/$tenantId/equipe'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<void> vincularUsuario(int userId, int tenantId) async {
    final response = await http.post(Uri.parse('$baseUrl/admin/usuario/vincular'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'tenant_id': tenantId}));
    if (response.statusCode != 200) throw Exception('Erro ao vincular');
  }

  Future<void> desvincularUsuario(int userId, int tenantId) async {
    final response = await http.post(Uri.parse('$baseUrl/admin/usuario/desvincular'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'tenant_id': tenantId}));
    if (response.statusCode != 200) throw Exception('Erro ao desvincular');
  }

  // --- BLOCOS E UNIDADES ---
  Future<void> criarBloco(int tenantId, String nome) async {
    await http.post(Uri.parse('$baseUrl/admin/bloco'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'tenant_id': tenantId, 'nome': nome}));
  }

  Future<void> gerarEstruturaCompleta(Map<String, dynamic> dados) async {
    final url = Uri.parse('$baseUrl/admin/bloco/estrutura-completa');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dados),
    );
    if (response.statusCode != 201) {
      final erro = jsonDecode(response.body);
      throw Exception(erro['error'] ?? 'Erro ao gerar estrutura');
    }
  }

  Future<List<dynamic>> getBlocos(int tenantId) async {
    final response = await http.get(Uri.parse('$baseUrl/admin/blocos/$tenantId'));
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getUnidadesPorBloco(int blocoId) async {
    final response = await http.get(Uri.parse('$baseUrl/admin/unidades/$blocoId'));
    return jsonDecode(response.body);
  }

  Future<void> criarUnidade(Map<String, dynamic> dados) async {
    await http.post(Uri.parse('$baseUrl/admin/unidade'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
  }

  Future<void> gerarUnidadesLote(Map<String, dynamic> dados) async {
    await http.post(Uri.parse('$baseUrl/admin/unidades/lote'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
  }

  // --- USUÁRIOS ---
  Future<List<dynamic>> getUsuarios() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/usuarios'));
    return jsonDecode(response.body);
  }

  Future<void> criarUsuario(Map<String, dynamic> dados) async {
    final response = await http.post(Uri.parse('$baseUrl/admin/usuario'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
    if (response.statusCode != 201) throw Exception('Erro ao criar usuário');
  }

  Future<void> editarUsuario(int id, Map<String, dynamic> dados) async {
    await http.put(Uri.parse('$baseUrl/admin/usuario/$id'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
  }

  Future<void> excluirUsuario(int id) async {
    await http.delete(Uri.parse('$baseUrl/admin/usuario/$id'));
  }

  // --- LEITURAS ---
  Future<List<dynamic>> getLeituras(int tenantId, {int? mes, int? ano, String? dtInicio, String? dtFim, int? blocoId}) async {
    String queryUrl = '$baseUrl/leitura/listar?tenant_id=$tenantId';
    if (dtInicio != null && dtFim != null) queryUrl += '&data_inicio=$dtInicio&data_fim=$dtFim';
    else if (mes != null && ano != null) queryUrl += '&mes=$mes&ano=$ano';
    if (blocoId != null) queryUrl += '&bloco_id=$blocoId';
    
    final response = await http.get(Uri.parse(queryUrl));
    return jsonDecode(response.body);
  }

  Future<void> corrigirLeitura(int id, double novoValor, {String? novaFotoBase64}) async {
    final body = {'novo_valor': novoValor, if (novaFotoBase64 != null) 'nova_foto': novaFotoBase64};
    await http.put(Uri.parse('$baseUrl/leitura/$id'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
  }

  Future<void> excluirLeitura(int id) async {
    await http.delete(Uri.parse('$baseUrl/leitura/$id'));
  }
}