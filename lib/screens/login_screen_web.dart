// ==========================================>>> login_screen_web.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main_web_screen.dart';
import '../services/api_service_web.dart'; // Ajuste o caminho se necessário

class LoginScreenWeb extends StatefulWidget {
  const LoginScreenWeb({super.key});

  @override
  _LoginScreenWebState createState() => _LoginScreenWebState();
}

class _LoginScreenWebState extends State<LoginScreenWeb> {
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final ApiServiceWeb _apiService = ApiServiceWeb();
  bool _isLoading = false;

  Future<void> _login() async {
    // Retira qualquer ponto ou traço que o usuário digitar, enviando só números
    String cpfDigitado = _cpfController.text.replaceAll(RegExp(r'[^0-9]'), '');
    String senhaDigitada = _passController.text.trim();

    if (cpfDigitado.isEmpty || senhaDigitada.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Informe o CPF e a Senha para entrar.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Chama o backend real lá no Render/Neon
      final user = await _apiService.login(cpfDigitado, senhaDigitada);
      
      // Salva os dados na memória do navegador para o sistema saber quem está logado
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('usuario_dados', jsonEncode(user));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainWebScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50], // Fundo levemente azulado para combinar
      body: Center(
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.apartment, size: 60, color: Colors.blue[900]),
                const SizedBox(height: 10),
                const Text("CONDOLOGIC", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const Text("PAINEL DE ADMINISTRAÇÃO", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 30),
                
                TextField(
                  controller: _cpfController, 
                  decoration: const InputDecoration(
                    labelText: "CPF (Apenas números)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 15),
                
                TextField(
                  controller: _passController, 
                  obscureText: true, 
                  decoration: const InputDecoration(
                    labelText: "Senha",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  )
                ),
                const SizedBox(height: 30),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text("ENTRAR NO PAINEL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}