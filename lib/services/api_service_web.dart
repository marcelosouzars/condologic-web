import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiServiceWeb {
  // APONTAMENTO OFICIAL PARA O RENDER - SUBSTITUINDO O LOCALHOST
  static const String baseUrl = 'https://condologic-backend.onrender.com/api';

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

  // --- CONDOMÍNIOS ---
  Future<List<dynamic>> getCondominios({int? usuarioId, String? nivel}) async {
    String query = '$baseUrl/admin/condominios';
    if (usuarioId != null) query += '?usuario_id=$usuarioId&nivel=$nivel';
    
    final response = await http.get(Uri.parse(query));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao carregar condomínios');
  }

  Future<void> criarCondominio(Map<String, dynamic> dados) async {
    final url = Uri.parse('$baseUrl/admin/condominio');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dados),
    );
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

  // --- BLOCOS ---
  Future<void> criarBloco(int tenantId, String nome) async {
    final url = Uri.parse('$baseUrl/admin/bloco');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tenant_id': tenantId,
        'nome': nome
      }),
    );
    if (response.statusCode != 201) throw Exception('Erro ao criar bloco');
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
    final url = Uri.parse('$baseUrl/admin/blocos/$tenantId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erro ao listar blocos');
    }
  }

  // --- UNIDADES ---
  Future<List<dynamic>> getUnidadesPorBloco(int blocoId) async {
    final url = Uri.parse('$baseUrl/admin/unidades/$blocoId');
    final response = await http.get(url);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao listar unidades');
  }

  Future<void> criarUnidade(Map<String, dynamic> dados) async {
    final url = Uri.parse('$baseUrl/admin/unidade');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dados),
    );
    if (response.statusCode != 201) throw Exception('Erro ao criar unidade');
  }

  Future<void> gerarUnidadesLote(Map<String, dynamic> dados) async {
    await http.post(Uri.parse('$baseUrl/admin/unidades/lote'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
  }

  // --- USUÁRIOS (CRUD COMPLETO) ---
  Future<List<dynamic>> getUsuarios() async {
    final url = Uri.parse('$baseUrl/admin/usuarios');
    final response = await http.get(url);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao listar usuários');
  }

  Future<void> criarUsuario(Map<String, dynamic> dados) async {
    final url = Uri.parse('$baseUrl/admin/usuario');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dados),
    );
    if (response.statusCode != 201) {
      final erro = jsonDecode(response.body);
      throw Exception(erro['error'] ?? 'Erro ao criar usuário');
    }
  }

  Future<void> editarUsuario(int id, Map<String, dynamic> dados) async {
    final url = Uri.parse('$baseUrl/admin/usuario/$id');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dados),
    );
    if (response.statusCode != 200) throw Exception('Erro ao editar usuário');
  }

  Future<void> excluirUsuario(int id) async {
    final url = Uri.parse('$baseUrl/admin/usuario/$id');
    final response = await http.delete(url);
    if (response.statusCode != 200) throw Exception('Erro ao excluir usuário');
  }

  // --- LEITURAS (CRUD) ---
  Future<List<dynamic>> getLeituras(int tenantId, {int? mes, int? ano, String? dtInicio, String? dtFim, int? blocoId}) async {
    String queryUrl = '$baseUrl/leitura/listar?tenant_id=$tenantId';
    if (dtInicio != null && dtFim != null) queryUrl += '&data_inicio=$dtInicio&data_fim=$dtFim';
    else if (mes != null && ano != null) queryUrl += '&mes=$mes&ano=$ano';
    if (blocoId != null) queryUrl += '&bloco_id=$blocoId';

    final response = await http.get(Uri.parse(queryUrl));
    return jsonDecode(response.body);
  }

  Future<void> corrigirLeitura(int id, double novoValor, {String? novaFotoBase64}) async {
    final url = Uri.parse('$baseUrl/leitura/$id');
    final body = {'novo_valor': novoValor, if (novaFotoBase64 != null) 'nova_foto': novaFotoBase64};
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) throw Exception('Erro ao corrigir leitura');
  }

  Future<void> excluirLeitura(int id) async {
    final url = Uri.parse('$baseUrl/leitura/$id');
    final response = await http.delete(url);
    if (response.statusCode != 200) throw Exception('Erro ao excluir leitura');
  }
}
// --- BUSCAR MEDIDORES ESPECÍFICOS DE UMA UNIDADE ---
  Future<List<dynamic>> getMedidoresUnidade(int tenantId, int unidadeId) async {
    final response = await http.get(Uri.parse('$baseUrl/dashboard/unidades?tenant_id=$tenantId'));
    if (response.statusCode == 200) {
      List<dynamic> todos = jsonDecode(response.body);
      return todos.where((item) => item['unidade_id'] == unidadeId).toList();
    }
    return [];
  }