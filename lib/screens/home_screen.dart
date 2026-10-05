import 'package:flutter/material.dart';

import '../services/api.dart';
import 'login_screen.dart';

/// Tela inicial provisória; será substituída pela lista de pacientes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _sair(BuildContext context) {
    api.token = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutri App'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => _sair(context),
          ),
        ],
      ),
      body: const Center(child: Text('Login realizado com sucesso.')),
    );
  }
}
