import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'camera_screen.dart';
import '../services/api_service_web.dart';
// ATENÇÃO: Nunca importe o database_helper.dart (sqflite) no projeto WEB!

class LeituraScreen extends StatefulWidget {
  final Map unidade;
  final Map medidor;

  const LeituraScreen({super.key, required this.unidade, required this.medidor});

  @override
  _LeituraScreenState createState() => _LeituraScreenState();
}

class _LeituraScreenState extends State<LeituraScreen> {
  String? _imagePath;
  List<int>? _imageBytes; // Usamos bytes diretamente para melhor suporte no Web
  bool _isProcessing = false;
  final String _baseUrl = "https://condologic-backend.onrender.com";

  Future<void> _capturarFoto() async {
    final Map<String, dynamic>? resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );

    if (resultado != null && resultado['path'] != null) {
      setState(() {
        _imagePath = resultado['path'];
        _imageBytes = resultado['bytes'];
      });
      _processarNoServidor();
    }
  }

  Future<void> _processarNoServidor() async {
    if (_imageBytes == null) {
      _mostrarErro("Nenhuma imagem para processar.");
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1. Decodifica e comprime a imagem (em memória, sem usar dart:io File)
      img.Image? originalImage = img.decodeImage(_imageBytes!);
      if (originalImage == null) throw Exception("Falha ao decodificar imagem");

      img.Image resizedImage = img.copyResize(originalImage, width: 800);
      List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 80);
      String base64Image = base64Encode(compressedBytes);

      // 2. Tenta enviar para o backend
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/api/leitura/processar-ia'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'image': base64Image,
            'medidor_id': widget.medidor['id'],
            'tenant_id': widget.unidade['tenant_id'],
            'leitura_anterior': widget.medidor['leitura_anterior']
          }),
        ).timeout(const Duration(seconds: 40));

        if (response.statusCode == 200) {
          _tratarRespostaIA(response.body);
        } else {
          // No Web, se falhar, apenas avisamos o erro. Não há banco offline (sqflite).
          _mostrarErro("Erro no servidor: ${response.statusCode}. Tente novamente.");
        }
      } catch (e) {
        // Timeout ou queda de internet no navegador
        _mostrarErro("Falha de conexão. Verifique sua internet e tente novamente.");
      }

    } catch (e) {
      _mostrarErro("Erro ao preparar foto: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _tratarRespostaIA(String corpo) {
    var leituraFinal = "Desconhecida";
    int casasDecimais = widget.medidor['digitos_vermelhos'] ?? 3;

    try {
      var data = jsonDecode(corpo);
      if (data is String) data = jsonDecode(data);

      if (data is Map) {
        double? parsedVal = double.tryParse(data['leitura'].toString());
        leituraFinal = parsedVal?.toStringAsFixed(casasDecimais) ?? data['leitura'].toString();
      }
      
      leituraFinal = leituraFinal.replaceAll('.', ',');
      _mostrarSucesso("A IA identificou o valor:\n\n$leituraFinal");
    } catch (e) {
      _mostrarSucesso("Leitura enviada! O sistema processará o valor.");
    }
  }

  void _mostrarSucesso(String mensagem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context, true); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("CONFIRMAR", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    String leituraAnteriorFormatada = widget.medidor['leitura_anterior'].toString().replaceAll('.', ',');

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text("Unidade ${widget.unidade['identificacao']}"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("MEDIDOR: ${widget.medidor['tipo_medidor'].toString().toUpperCase()}", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 10),
          Text("Leitura Anterior: $leituraAnteriorFormatada", style: TextStyle(color: Colors.grey[700], fontSize: 16)),
          const SizedBox(height: 40),
          Center(
            child: _imagePath == null
                ? Icon(Icons.image_search, size: 150, color: Colors.blue[100])
                : Container(
                    height: 180, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue[900]!, width: 3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    // No Flutter Web, o NetworkImage consegue carregar URLs de blob gerados pela câmera
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(_imagePath!, fit: BoxFit.cover),
                    ),
                  ),
          ),
          const SizedBox(height: 50),
          if (_isProcessing)
            Column(children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text("PROCESSANDO...", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold))])
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity, height: 70,
                child: ElevatedButton.icon(
                  onPressed: _capturarFoto,
                  icon: const Icon(Icons.camera_alt, size: 30),
                  label: const Text("TIRAR FOTO DO RELÓGIO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}