// ==========================================>>> login_screen.dart

import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

 void _login() {
    String userDigitado = _userController.text.trim();
    String senhaDigitada = _passController.text.trim();

    // Aceita com pontos ou apenas números para não ter erro
    if ((userDigitado == "000.000.000-00" || userDigitado == "00000000000") && senhaDigitada == "123456") {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => MainWebScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuário ou senha inválidos. Tente CPF e 123456.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("CONDOLOGIC - Login")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _cpfController, decoration: InputDecoration(labelText: "CPF")),
            TextField(controller: _passController, obscureText: true, decoration: InputDecoration(labelText: "Senha")),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _fazerLogin, child: Text("ENTRAR")),
          ],
        ),
      ),
    );
  }
}