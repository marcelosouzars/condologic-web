// ==========================================>>> api_service_web.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; 

class ApiServiceWeb {
  static const String baseUrl = 'https://condologic-backend.onrender.com/api';

  // ==========================================
  // GESTÃO DE SESSÃO WEB (BLINDAGEM CONTRA F5)
  // ==========================================
  Future<void> salvarSessao(Map<String, dynamic> usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usuarioLogado', jsonEncode(usuario));
  }

  Future<Map<String, dynamic>?> recuperarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userData = prefs.getString('usuarioLogado');
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }

  Future<void> limparSessao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuarioLogado');
  }

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
        final data = jsonDecode(response.body);
        await salvarSessao(data); 
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erro desconhecido');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // --- ALTERAR SENHA ---
  Future<void> alterarSenha(int userId, String senhaAtual, String novaSenha) async {
    final url = Uri.parse('$baseUrl/auth/alterar-senha');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': userId,
        'senha_atual': senhaAtual,
        'nova_senha': novaSenha
      }),
    );
    if (response.statusCode != 200) {
      final erro = jsonDecode(response.body);
      throw Exception(erro['error'] ?? 'Erro ao alterar a senha.');
    }
  }

  // --- CONDOMÍNIOS ---
  Future<List<dynamic>> getCondominios({int? usuarioId, String? nivel}) async {
    String query = '$baseUrl/admin/condominios';
    if (usuarioId != null) query += '?usuario_id=$userId&nivel=$nivel';
    final response = await http.get(Uri.parse(query));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao carregar condomínios');
  }

  // --- NOVO MÉTODO: BUSCA DADOS PARA A PLANILHA DA ADMINISTRADORA ---
  Future<List<dynamic>> getLeiturasParaAdministradora(int tenantId, String dtInicio, String dtFim) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leitura/exportar-admin?tenant_id=$tenantId&data_inicio=$dtInicio&data_fim=$dtFim'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Falha ao carregar dados para exportação');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // --- ANTIGA ROTA DE EXPORTAÇÃO (MANTIDA PARA COMPATIBILIDADE) ---
  Future<List<dynamic>> getLeiturasParaExportacao(int tenantId, String mesReferencia) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leitura/exportar?tenant_id=$tenantId&mes_referencia=$mesReferencia'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Falha ao carregar dados para exportação');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  Future<void> criarCondominio(Map<String, dynamic> dados, {int? usuarioId, String? nivel}) async {
    final url = Uri.parse('$baseUrl/admin/condominio');
    final corpo = Map<String, dynamic>.from(dados);
    if (usuarioId != null) corpo['usuario_id'] = usuarioId;
    if (nivel != null) corpo['nivel'] = nivel;
    final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(corpo));
    if (response.statusCode != 201) throw Exception('Erro ao criar: ${response.body}');
  }

  Future<void> editarCondominio(int id, Map<String, dynamic> dados) async {
    final response = await http.put(Uri.parse('$baseUrl/admin/condominio/$id'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
    if (response.statusCode != 200) throw Exception('Erro ao editar');
  }

  Future<void> excluirCondominio(int id, String nivelAcesso) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/condominio/$id?nivel=$nivelAcesso'));
    if (response.statusCode != 200) {
      final erro = jsonDecode(response.body);
      throw Exception(erro['error'] ?? 'Erro ao excluir');
    }
  }

  // --- EQUIPE, BLOCOS, UNIDADES E USUÁRIOS (MANTIDOS INTEGRALMENTE) ---
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

  Future<int> criarBloco(int tenantId, String nome) async {
    final url = Uri.parse('$baseUrl/admin/bloco');
    final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'tenant_id': tenantId, 'nome': nome}));
    if (response.statusCode == 201) return jsonDecode(response.body)['id'];
    throw Exception('Erro ao criar bloco');
  }

  Future<List<dynamic>> getBlocos(int tenantId) async {
    final response = await http.get(Uri.parse('$baseUrl/admin/blocos/$tenantId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao listar blocos');
  }

  Future<void> excluirBloco(int blocoId, String nivelAcesso) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/bloco/$blocoId?nivel=$nivelAcesso'));
    if (response.statusCode != 200) throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao excluir bloco');
  }

  Future<void> gerarEstruturaCompleta(Map<String, dynamic> dados) async {
    final response = await http.post(Uri.parse('$baseUrl/admin/bloco/estrutura-completa'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
    if (response.statusCode != 201) throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao gerar estrutura');
  }

  Future<List<dynamic>> getUnidadesPorBloco(int blocoId) async {
    final response = await http.get(Uri.parse('$baseUrl/admin/unidades/$blocoId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao listar unidades');
  }

  Future<void> criarUnidade(Map<String, dynamic> dados) async {
    final response = await http.post(Uri.parse('$baseUrl/admin/unidade'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
    if (response.statusCode != 201) throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao criar unidade');
  }

  Future<void> excluirUnidade(int blocoId, String identificacao) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/unidade/$blocoId/$identificacao'));
    if (response.statusCode != 200) throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao excluir unidade');
  }

  Future<void> gerarUnidadesLote(Map<String, dynamic> dados) async {
    await http.post(Uri.parse('$baseUrl/admin/unidades/lote'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
  }

  Future<void> gerarUnidadesInteligente(Map<String, dynamic> dados) async {
    final response = await http.post(Uri.parse('$baseUrl/admin/unidades/gerador-inteligente'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
    if (response.statusCode != 201) throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao gerar unidades');
  }

  Future<List<dynamic>> getUsuarios() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/usuarios'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao listar usuários');
  }

  Future<void> criarUsuario(Map<String, dynamic> dados) async {
    final response = await http.post(Uri.parse('$baseUrl/admin/usuario'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
    if (response.statusCode != 201) throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao criar usuário');
  }

  Future<void> editarUsuario(int id, Map<String, dynamic> dados) async {
    final response = await http.put(Uri.parse('$baseUrl/admin/usuario/$id'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
    if (response.statusCode != 200) throw Exception('Erro ao editar usuário');
  }

  Future<void> excluirUsuario(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/usuario/$id'));
    if (response.statusCode != 200) throw Exception('Erro ao excluir usuário');
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
    final url = Uri.parse('$baseUrl/leitura/$id');
    final body = {'novo_valor': novoValor, if (novaFotoBase64 != null) 'nova_foto': novaFotoBase64};
    final response = await http.put(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (response.statusCode != 200) throw Exception('Erro ao corrigir leitura');
  }

  Future<void> excluirLeitura(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/leitura/$id'));
    if (response.statusCode != 200) throw Exception('Erro ao excluir leitura');
  }

  Future<void> incluirLeituraManual(Map<String, dynamic> dados) async {
    final response = await http.post(Uri.parse('$baseUrl/leitura/manual'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));
    if (response.statusCode != 201) throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao incluir leitura manual');
  }

  Future<List<dynamic>> getMedidoresUnidade(int tenantId, int unidadeId) async {
    final response = await http.get(Uri.parse('$baseUrl/dashboard/unidades?tenant_id=$tenantId'));
    if (response.statusCode == 200) {
      List<dynamic> todos = jsonDecode(response.body);
      return todos.where((item) => item['unidade_id'] == unidadeId).toList();
    }
    return [];
  }

  // --- AUDITORIA E IMPORTAÇÃO (MANTIDOS) ---
  Future<Map<String, dynamic>> getResumoAlertas(int tenantId) async {
    final response = await http.get(Uri.parse('$baseUrl/admin/dashboard/alertas?tenant_id=$tenantId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {'total_alertas': 0};
  }

  Future<List<dynamic>> getLeiturasAuditoria(int tenantId) async {
    final response = await http.get(Uri.parse('$baseUrl/admin/leituras/auditoria/$tenantId'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erro ao carregar lista de auditoria');
  }

  Future<void> auditarLeitura(int leituraId, String acao, String novoValor, String observacao) async {
    final response = await http.put(Uri.parse('$baseUrl/admin/leitura/auditar/$leituraId'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'acao': acao, 'novo_valor': novoValor, 'observacao': observacao}));
    if (response.statusCode != 200) throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao auditar');
  }

  Future<Map<String, dynamic>> importarHistorico(int tenantId, List<Map<String, dynamic>> dados) async {
    final response = await http.post(Uri.parse('$baseUrl/importacao/historico'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'tenant_id': tenantId, 'dados': dados}));
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception(jsonDecode(response.body)['error'] ?? 'Erro na importação.');
  }
}