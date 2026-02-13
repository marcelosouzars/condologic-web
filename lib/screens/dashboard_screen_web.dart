import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen_web.dart';
import 'condominios_screen_web.dart';
import 'usuarios_screen_web.dart'; 
import 'leituras_screen_web.dart';
import 'relatorios_screen_web.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData; // Recebe os dados de quem logou

  const DashboardScreen({super.key, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Controle de qual tela está sendo exibida no centro
  String _telaAtual = 'inicio';

  @override
  Widget build(BuildContext context) {
    final nomeUsuario = widget.userData['user']['nome'];
    final nivelAcesso = widget.userData['user']['nivel']; // 'master' ou 'operador'
    final isMaster = nivelAcesso == 'master';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(
        children: [
          // ===============================================
          // MENU LATERAL (SIDEBAR) - DESIGN AZUL (O QUE VOCÊ GOSTA)
          // ===============================================
          Container(
            width: 260,
            color: Colors.blue[900], // Azul Escuro Clássico
            child: Column(
              children: [
                // 1. Logo / Título do App
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
                      const SizedBox(height: 10),
                      Text(
                        'CondoLogic',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Gestão Inteligente',
                        style: GoogleFonts.montserrat(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white24),

                // 2. Itens do Menu
                _buildMenuItem(
                  icon: Icons.dashboard, 
                  label: 'Visão Geral', 
                  id: 'inicio',
                  isActive: _telaAtual == 'inicio'
                ),

                // Lógica de Segurança: Só mostra esses se for MASTER
                if (isMaster) ...[
                  _buildSectionTitle('ADMINISTRAÇÃO'),
                  _buildMenuItem(
                    icon: Icons.business, 
                    label: 'Condomínios', 
                    id: 'condominios',
                    isActive: _telaAtual == 'condominios'
                  ),
                  _buildMenuItem(
                    icon: Icons.people, 
                    label: 'Usuários & Equipe', // <--- Nome Ajustado
                    id: 'usuarios',
                    isActive: _telaAtual == 'usuarios'
                  ),
                ],

                _buildSectionTitle('OPERACIONAL'),
                _buildMenuItem(
                  icon: Icons.water_drop, 
                  label: 'Leituras & Consumo', 
                  id: 'leituras',
                  isActive: _telaAtual == 'leituras'
                ),
                _buildMenuItem(
                  icon: Icons.bar_chart, 
                  label: 'Relatórios', 
                  id: 'relatorios',
                  isActive: _telaAtual == 'relatorios'
                ),

                // Se não for master, mostra as unidades dele
                if (!isMaster) ...[
                  _buildMenuItem(
                    icon: Icons.apartment, 
                    label: 'Minhas Unidades', 
                    id: 'unidades',
                    isActive: _telaAtual == 'unidades'
                  ),
                ],

                // Empurra o botão Sair para o rodapé
                const Spacer(),
                const Divider(color: Colors.white24),

                // 3. Botão SAIR (Fixo embaixo)
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                  title: Text(
                    'SAIR DO SISTEMA',
                    style: GoogleFonts.montserrat(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                     Navigator.pushReplacement(
                       context, 
                       MaterialPageRoute(builder: (context) => const LoginScreen())
                     );
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                ),
              ],
            ),
          ),

          // ===============================================
          // ÁREA DE CONTEÚDO (DIREITA)
          // ===============================================
          Expanded(
            child: Column(
              children: [
                // Barra Superior (Header) - Mantive do código branco pois é útil
                Container(
                  height: 60,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(nomeUsuario, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            isMaster ? 'Super Administrador' : 'Gestor de Condomínio',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Icon(Icons.person, color: Colors.blue[800]),
                      ),
                    ],
                  ),
                ),

                // O Conteúdo da Tela
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildConteudoCentral(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar estilizado para o Menu Azul
  Widget _buildMenuItem({required IconData icon, required String label, required String id, required bool isActive}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _telaAtual = id),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
            border: isActive 
                ? const Border(left: BorderSide(color: Colors.white, width: 4)) 
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white30),
        ),
      ),
    );
  }

  // Conteúdo Central (Lógica do Switch Case)
  Widget _buildConteudoCentral() {
    switch (_telaAtual) {
      case 'inicio':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics, size: 100, color: Colors.blue[100]),
              const SizedBox(height: 20),
              Text(
                "Bem-vindo ao Dashboard",
                style: GoogleFonts.montserrat(fontSize: 24, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      
      case 'condominios':
        return const CondominiosScreenWeb();
      
      case 'usuarios': 
        return const UsuariosScreenWeb();

      case 'leituras': 
        return const LeiturasScreenWeb();

      case 'relatorios':
        return const RelatoriosScreenWeb();

      case 'unidades':
        return const Center(child: Text("Gestão de Unidades (Visão Síndico)"));
        
      default:
        return Center(child: Text("Tela: $_telaAtual"));
    }
  }
}