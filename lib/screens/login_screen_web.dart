// ==========================================>>> login_screen_web.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui'; // <--- NOVO: Necessário para o ImageFilter (Glassmorfismo)
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
  
  // Controle de Estado da Tela
  AuthMode _mode = AuthMode.login;
  bool _isLoading = false;
  String _emailParaValidacao = '';

  // Controladores do Login
  final TextEditingController _cpfLoginCtrl = TextEditingController();
  final TextEditingController _passLoginCtrl = TextEditingController();

  // Controladores do Registro
  final TextEditingController _nomeRegCtrl = TextEditingController();
  final TextEditingController _cpfRegCtrl = TextEditingController();
  final TextEditingController _emailRegCtrl = TextEditingController();
  final TextEditingController _telefoneRegCtrl = TextEditingController();
  final TextEditingController _senhaRegCtrl = TextEditingController();

  // Controlador da Validação
  final TextEditingController _codigoCtrl = TextEditingController();

  // =========================================================================
  // FUNÇÃO 1: LOGIN TRADICIONAL
  // =========================================================================
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
              content: const Text("Seu perfil de usuário não tem permissão para acessar o Painel Web.\n\nPor favor, utilize o Aplicativo Mobile (Celular) para realizar suas tarefas de leitura."),
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

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainWebScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // FUNÇÃO 2: REGISTRAR NOVO SÍNDICO
  // =========================================================================
  Future<void> _registrarSindico() async {
    if (_nomeRegCtrl.text.isEmpty || _cpfRegCtrl.text.isEmpty || _emailRegCtrl.text.isEmpty || _senhaRegCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos obrigatórios.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dados = {
        'nome': _nomeRegCtrl.text.trim(),
        'cpf': _cpfRegCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'email': _emailRegCtrl.text.trim(),
        'telefone': _telefoneRegCtrl.text.trim(),
        'senha': _senhaRegCtrl.text.trim(),
      };

      await _apiService.registrarSindico(dados);
      
      setState(() {
        _emailParaValidacao = _emailRegCtrl.text.trim();
        _mode = AuthMode.validate; // Avança para a tela de código
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cadastro prévio realizado! Verifique seu e-mail."), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // FUNÇÃO 3: VALIDAR O CÓDIGO DO RESEND
  // =========================================================================
  Future<void> _validarCodigo() async {
    if (_codigoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Informe o código de 6 dígitos.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _apiService.validarCodigoVerificacao(_emailParaValidacao, _codigoCtrl.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conta ativada com sucesso! Faça seu login."), backgroundColor: Colors.green));
      }

      // Preenche o CPF e a senha no login para facilitar
      setState(() {
        _cpfLoginCtrl.text = _cpfRegCtrl.text;
        _passLoginCtrl.text = _senhaRegCtrl.text;
        _mode = AuthMode.login;
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // CONSTRUTORES DE TELA DENTRO DO CARD DE VIDRO
  // =========================================================================
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
            child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text("ENTRAR NO PAINEL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      children: [
        const Text("CRIAR CONTA DE SÍNDICO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 20),
        TextField(controller: _nomeRegCtrl, decoration: const InputDecoration(labelText: "Nome Completo*", border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 10),
        TextField(controller: _cpfRegCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "CPF*", border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 10),
        TextField(controller: _emailRegCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "E-mail válido*", border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 10),
        TextField(controller: _telefoneRegCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefone/WhatsApp", border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 10),
        TextField(controller: _senhaRegCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Criar uma Senha*", border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _registrarSindico, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text("CONTINUAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _mode = AuthMode.login),
          child: const Text("Voltar para o Login", style: TextStyle(color: Colors.grey)),
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
            child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text("VALIDAR CÓDIGO E ATIVAR CONTA", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
          // 1. Imagem de Fundo
          Positioned.fill(
            child: Image.asset('assets/images/background_web.png', fit: BoxFit.cover)
          ),
          
          // 2. Película escura para dar contraste
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Color(0x80000000), BlendMode.srcOver), 
              child: const SizedBox()
            )
          ),
          
          // 3. EFEITO GLASSMORFISMO AQUI
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20), // Arredondamento do vidro
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0), // Intensidade do desfoque
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 450,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.80), // Fundo branco translúcido
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5), // Borda brilhante do vidro
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/logo_condologic.png', height: 80, errorBuilder: (c, e, s) => Icon(Icons.apartment, size: 80, color: Colors.blue[900])),
                      const SizedBox(height: 10),
                      const Text("CONDOLOGIC", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const Text("PAINEL DO SÍNDICO", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 30),
                      
                      // Chama a máquina de estados
                      if (_mode == AuthMode.login) _buildLoginForm(),
                      if (_mode == AuthMode.register) _buildRegisterForm(),
                      if (_mode == AuthMode.validate) _buildValidateForm(),
                    ],
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