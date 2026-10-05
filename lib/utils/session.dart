import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../services/api.dart';
import '../services/apps_script_client.dart';

/// Verdadeiro quando o servidor recusou o token (sessão vencida).
bool sessaoExpirada(Object e) => e is ApiException && e.code == 'unauthorized';

/// Encerra a sessão e volta para o login, limpando a navegação.
void irParaLogin(BuildContext context) {
  api.token = null;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}
