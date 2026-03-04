
import 'package:flutter/material.dart';
import 'screens/login_screen_web.dart'; // Ajuste o caminho se necessário

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CondoLogicApp());
}

class CondoLogicApp extends StatelessWidget {
  const CondoLogicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CondoLogic Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // REMOVEMOS O 'const' DAQUI TAMBÉM:
      home: LoginScreenWeb(), 
    );
  }
}