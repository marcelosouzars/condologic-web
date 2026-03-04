// ==========================================>>> login_screen_web.dart
import 'package:flutter/material.dart';
import 'main_web_screen.dart'; // Na web, usamos o MainWebScreen

class LoginScreenWeb extends StatefulWidget {
  @override
  _LoginScreenWebState createState() => _LoginScreenWebState();
}

class _LoginScreenWebState extends State<LoginScreenWeb> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  void _login() {
    String userDigitado = _userController.text.trim();
    String senhaDigitada = _passController.text.trim();

    // Login Master aceitando com ou sem pontos
    if ((userDigitado == "000.000.000-00" || userDigitado == "00000000000") && senhaDigitada == "123456") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainWebScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuário ou senha inválidos")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("CONDOLOGIC ADMIN", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              TextField(controller: _userController, decoration: InputDecoration(labelText: "CPF (Usuário)")),
              SizedBox(height: 10),
              TextField(controller: _passController, obscureText: true, decoration: InputDecoration(labelText: "Senha")),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _login, child: Text("ENTRAR NO PAINEL")),
            ],
          ),
        ),
      ),
    );
  }
}