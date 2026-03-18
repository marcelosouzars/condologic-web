import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // PACOTE DE TRADUÇÃO
import 'screens/login_screen_web.dart';

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
      
      // ==========================================
      // CONFIGURAÇÃO DE IDIOMA PARA PT-BR (CALENDÁRIOS)
      // ==========================================
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: LoginScreenWeb(), 
    );
  }
}