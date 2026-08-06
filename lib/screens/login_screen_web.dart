// ==========================================>>> login_screen_web.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';
import 'main_web_screen.dart';
import '../services/api_service_web.dart';

enum AuthMode { login, register, validate }

class LoginScreenWeb extends StatefulWidget {
  const LoginScreenWeb({super.key});

  @override
  _LoginScreenWebState createState() => _LoginScreenWebState();
}

class _LoginScreenWebState extends State<LoginScreenWeb> {
  final ApiServiceWeb _apiService = ApiServiceWeb();
  
  AuthMode _mode = AuthMode.login;
  bool _isLoading = false;
  String _emailParaValidacao = '';

  // Controladores do Login
  final TextEditingController _cpfLoginCtrl = TextEditingController();
  final TextEditingController _passLoginCtrl = TextEditingController();

  // Controladores do Registro - Dados Pessoais
  final TextEditingController _nomeRegCtrl = TextEditingController();
  final TextEditingController _cpfRegCtrl = TextEditingController();
  final TextEditingController _nascimentoRegCtrl = TextEditingController();
  final TextEditingController _emailRegCtrl = TextEditingController();
  final TextEditingController _telefoneRegCtrl = TextEditingController();
  
  // Controladores do Registro - Endereço
  final TextEditingController _cepRegCtrl = TextEditingController();
  final TextEditingController _logradouroRegCtrl = TextEditingController();
  final TextEditingController _numeroRegCtrl = TextEditingController();
  final TextEditingController _complementoRegCtrl = TextEditingController();
  final TextEditingController _bairroRegCtrl = TextEditingController();
  final TextEditingController _cidadeRegCtrl = TextEditingController();
  final TextEditingController _estadoRegCtrl = TextEditingController();

  // Controladores do Registro - Segurança
  final TextEditingController _senhaRegCtrl = TextEditingController();
  final TextEditingController _confirmaSenhaRegCtrl = TextEditingController();

  // Validações de Senha
  bool _hasMinLength = false;
  bool _hasUpper = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  // Controlador da Validação de Email
  final TextEditingController _codigoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Monitora a digitação da senha para atualizar o checklist
    _senhaRegCtrl.addListener(() {
      final text = _senhaRegCtrl.text;
      setState(() {
        _hasMinLength = text.length >= 6;
        _hasUpper = text.contains(RegExp(r'[A-Z]'));
        _hasNumber = text.contains(RegExp(r'[0-9]'));
        _hasSpecial = text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
      });
    });
  }

  @override
  void dispose() {
    _senhaRegCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    String cpfDigitado = _cpfLoginCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    String senhaDigitada = _passLoginCtrl.text.trim();

    if (cpfDigitado.isEmpty || senhaDigitada.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Informe o CPF e a Senha para entrar.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _apiService.login(cpfDigitado, senhaDigitada);
      
      String nivelAcesso = user['nivel_acesso']?.toString().toLowerCase() ?? user['nivel']?.toString().toLowerCase() ?? 'usuario';
      
      if (nivelAcesso != 'admin' && nivelAcesso != 'master') {
        setState(() => _isLoading = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 10), Text("Acesso Negado")]),
              content: const Text("Seu perfil de usuário não tem permissão para acessar o Painel Web.\n\nPor favor, utilize o Aplicativo Mobile para tarefas de leitura."),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                  child: const Text("ENTENDI", style: TextStyle(color: Colors.white)),
                )
              ],
            )
          );
        }
        return; 
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('usuario_dados', jsonEncode(user));

      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainWebScreen()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registrarSindico() async {
    if (_nomeRegCtrl.text.isEmpty || _cpfRegCtrl.text.isEmpty || _emailRegCtrl.text.isEmpty || _senhaRegCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos obrigatórios (*)."), backgroundColor: Colors.red));
      return;
    }

    if (!_hasMinLength || !_hasUpper || !_hasNumber || !_hasSpecial) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A senha não atende aos critérios de segurança."), backgroundColor: Colors.red));
      return;
    }

    if (_senhaRegCtrl.text != _confirmaSenhaRegCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("As senhas digitadas não coincidem."), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Ajuste de Data de Nascimento para o Banco de Dados (DD/MM/AAAA -> AAAA-MM-DD)
      String dNasc = _nascimentoRegCtrl.text.trim();
      if (dNasc.length == 10 && dNasc.contains('/')) {
        var p = dNasc.split('/');
        dNasc = '${p[2]}-${p[1]}-${p[0]}';
      }

      final dados = {
        'nome': _nomeRegCtrl.text.trim(),
        'cpf': _cpfRegCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'email': _emailRegCtrl.text.trim(),
        'telefone': _telefoneRegCtrl.text.trim(),
        'senha': _senhaRegCtrl.text.trim(),
        'cep': _cepRegCtrl.text.trim(),
        'logradouro': _logradouroRegCtrl.text.trim(),
        'numero': _numeroRegCtrl.text.trim(),
        'complemento': _complementoRegCtrl.text.trim(),
        'bairro': _bairroRegCtrl.text.trim(),
        'cidade': _cidadeRegCtrl.text.trim(),
        'estado': _estadoRegCtrl.text.trim(),
        'data_nascimento': dNasc,
      };

      await _apiService.registrarSindico(dados);
      
      setState(() {
        _emailParaValidacao = _emailRegCtrl.text.trim();
        _mode = AuthMode.validate;
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cadastro realizado! Verifique seu e-mail."), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _validarCodigo() async {
    if (_codigoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Informe o código de 6 dígitos.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _apiService.validarCodigoVerificacao(_emailParaValidacao, _codigoCtrl.text.trim());
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conta ativada com sucesso! Faça seu login."), backgroundColor: Colors.green));

      setState(() {
        _cpfLoginCtrl.text = _cpfRegCtrl.text;
        _passLoginCtrl.text = _senhaRegCtrl.text;
        _mode = AuthMode.login;
      });

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- COMPONENTES VISUAIS ---
  
  Widget _buildCheckItem(String texto, bool atendido) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(atendido ? Icons.check_circle : Icons.radio_button_unchecked, color: atendido ? Colors.green : Colors.grey[700], size: 16),
          const SizedBox(width: 6),
          Text(texto, style: TextStyle(color: atendido ? Colors.green[800] : Colors.grey[700], fontSize: 12, fontWeight: atendido ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _cpfLoginCtrl, 
          decoration: const InputDecoration(labelText: "CPF (Apenas números)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _passLoginCtrl, 
          obscureText: true, 
          decoration: const InputDecoration(labelText: "Senha", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
            child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("ENTRAR NO PAINEL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(),
        TextButton(
          onPressed: () => setState(() => _mode = AuthMode.register),
          child: const Text("É Síndico e ainda não tem conta? Cadastre-se aqui", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: const Text("CRIAR CONTA DE SÍNDICO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue))),
        const SizedBox(height: 20),
        
        const Text("1. Dados Pessoais", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: TextField(controller: _nomeRegCtrl, decoration: const InputDecoration(labelText: "Nome Completo*", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _cpfRegCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "CPF*", border: OutlineInputBorder(), isDense: true))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: TextField(controller: _emailRegCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "E-mail válido*", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _telefoneRegCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "WhatsApp / Fixo*", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _nascimentoRegCtrl, decoration: const InputDecoration(labelText: "Nascimento (DD/MM/AAAA)", border: OutlineInputBorder(), isDense: true))),
          ],
        ),

        const SizedBox(height: 20),
        const Text("2. Endereço", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(flex: 1, child: TextField(controller: _cepRegCtrl, decoration: const InputDecoration(labelText: "CEP*", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: TextField(controller: _logradouroRegCtrl, decoration: const InputDecoration(labelText: "Logradouro (Rua, Av)*", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: TextField(controller: _numeroRegCtrl, decoration: const InputDecoration(labelText: "Número*", border: OutlineInputBorder(), isDense: true))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: TextField(controller: _complementoRegCtrl, decoration: const InputDecoration(labelText: "Complemento", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _bairroRegCtrl, decoration: const InputDecoration(labelText: "Bairro*", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _cidadeRegCtrl, decoration: const InputDecoration(labelText: "Cidade*", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 10),
            SizedBox(width: 80, child: TextField(controller: _estadoRegCtrl, decoration: const InputDecoration(labelText: "UF*", border: OutlineInputBorder(), isDense: true))),
          ],
        ),

        const SizedBox(height: 20),
        const Text("3. Segurança", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  TextField(controller: _senhaRegCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Criar Senha*", border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 10),
                  TextField(controller: _confirmaSenhaRegCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Confirmar Senha*", border: OutlineInputBorder(), isDense: true)),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blueGrey.withOpacity(0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("A senha deve conter:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 5),
                    _buildCheckItem("No mínimo 6 caracteres", _hasMinLength),
                    _buildCheckItem("Ao menos 1 letra maiúscula", _hasUpper),
                    _buildCheckItem("Ao menos 1 número", _hasNumber),
                    _buildCheckItem("Ao menos 1 caractere especial (@, !, #, etc)", _hasSpecial),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _registrarSindico, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("FINALIZAR CADASTRO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 5),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _mode = AuthMode.login),
            child: const Text("Voltar para o Login", style: TextStyle(color: Colors.grey)),
          ),
        )
      ],
    );
  }

  Widget _buildValidateForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read, size: 60, color: Colors.green),
        const SizedBox(height: 15),
        const Text("VERIFIQUE SEU E-MAIL", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 10),
        Text("Enviamos um código de 6 dígitos para o e-mail:\n$_emailParaValidacao", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        TextField(
          controller: _codigoCtrl, 
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(hintText: "000000", border: OutlineInputBorder())
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _validarCodigo, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
            child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("VALIDAR CÓDIGO E ATIVAR CONTA", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _mode = AuthMode.register),
          child: const Text("Corrigir E-mail / Voltar", style: TextStyle(color: Colors.grey)),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/fundo_web.png', fit: BoxFit.cover)),
          Positioned.fill(child: ColorFiltered(colorFilter: const ColorFilter.mode(Color(0x80000000), BlendMode.srcOver), child: const SizedBox())),
          
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  // Expande a largura para caber as colunas do formulário
                  width: _mode == AuthMode.register ? 750 : 450,
                  // Trava a altura máxima para não vazar a tela e ativa a rolagem interna
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.90,
                  ),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.60), width: 1.5),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/images/logo_condologic.png', height: 80, errorBuilder: (c, e, s) => Icon(Icons.apartment, size: 80, color: Colors.blue[900])),
                        const SizedBox(height: 10),
                        const Text("CONDOLOGIC", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const Text("PAINEL DO SÍNDICO", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 30),
                        
                        if (_mode == AuthMode.login) _buildLoginForm(),
                        if (_mode == AuthMode.register) _buildRegisterForm(),
                        if (_mode == AuthMode.validate) _buildValidateForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}