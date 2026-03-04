// ==========================================>>> login_screen_web.dart

import 'package:flutter/material.dart';
import 'main_web_screen.dart'; // Certifique-se que o import está correto

class LoginScreenWeb extends StatefulWidget {
  @override
  _LoginScreenWebState createState() => _LoginScreenWebState();
}

class _LoginScreenWebState extends State<LoginScreenWeb> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  void _login() {
    // Simulação de login para o síndico
    // No futuro, você pode conectar com /api/login do backend
    if (_userController.text == "admin" && _passController.text == "condo123") {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => MainWebScreen(), // REMOVIDO O 'const' DAQUI
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Usuário ou senha inválidos")),
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("CONDOLOGIC ADMIN", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              SizedBox(height: 30),
              TextField(
                controller: _userController,
                decoration: InputDecoration(labelText: "Usuário", border: OutlineInputBorder()),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: InputDecoration(labelText: "Senha", border: OutlineInputBorder()),
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _login,
                  child: Text("ENTRAR NO PAINEL"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}