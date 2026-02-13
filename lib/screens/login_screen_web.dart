import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service_web.dart';
import 'main_web_screen.dart';

class LoginScreenWeb extends StatefulWidget {
  const LoginScreenWeb({super.key});
  @override
  State<LoginScreenWeb> createState() => _LoginScreenWebState();
}

class _LoginScreenWebState extends State<LoginScreenWeb> {
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  final _apiService = ApiServiceWeb();
  bool _isLoading = false;

  Future<void> _fazerLogin() async {
    setState(() => _isLoading = true);
    try {
      final resultado = await _apiService.login(
        _cpfController.text,
        _senhaController.text,
      );

      final nivel = resultado['user']['nivel']; 
      final tipo = resultado['user']['role'];  

      // Trava de segurança visual
      if (nivel != 'master' && tipo != 'sindico') {
        throw Exception('Acesso restrito! Zeladores devem usar o App.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', 'sessao_ativa'); 
      await prefs.setString('usuario_dados', jsonEncode(resultado['user']));

      if (!mounted) return;
      // Animação suave na troca de tela
      Navigator.pushReplacement(
        context, 
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainWebScreen(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        )
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fundo com gradiente suave para ficar moderno
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[900]!, Colors.blue[600]!],
          ),
        ),
        child: Center(
          child: Card(
            elevation: 10, // Sombra bonita
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_moon, size: 70, color: Colors.blue[900]),
                  const SizedBox(height: 20),
                  Text('CondoLogic', style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                  Text('Painel Administrativo', style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 40),
                  
                  TextField(
                    controller: _cpfController, 
                    decoration: const InputDecoration(labelText: 'CPF', prefixIcon: Icon(Icons.person_outline))
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _senhaController, 
                    obscureText: true, 
                    decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.lock_outline))
                  ),
                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity, 
                    height: 50, 
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _fazerLogin, 
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text('ENTRAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                    )
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}