import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Importe o arquivo correto do login WEB
import 'screens/login_screen_web.dart';

void main() {
  runApp(const WebAdminApp());
}

class WebAdminApp extends StatelessWidget {
  const WebAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CondoLogic Admin',
      debugShowCheckedModeBanner: false, // Remove a faixa "Debug" feia
      theme: ThemeData(
        // Define a cor base como Azul Marinho
        primarySwatch: Colors.blue,
        primaryColor: Colors.blue[900],
        scaffoldBackgroundColor: Colors.blue[50], // Fundo azulzinho suave
        
        // Define a fonte bonita para todo o app
        textTheme: GoogleFonts.montserratTextTheme(
          Theme.of(context).textTheme,
        ),
        
        // Estilo dos botões
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[900], // Botões escuros
            foregroundColor: Colors.white,     // Texto branco
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        
        // Inputs bonitos
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
        ),
        
        useMaterial3: false, 
      ),
      home: const LoginScreenWeb(),
    );
  }
}