import 'package:flutter/material.dart';

import '../services/api.dart';
import '../utils/friendly_error.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _senha = TextEditingController();
  final _codigo = TextEditingController();
  final _confirma = TextEditingController();

  bool _primeiroAcesso = false;
  bool _loading = false;
  bool _ver = false;
  String? _erro;

  @override
  void dispose() {
    _senha.dispose();
    _codigo.dispose();
    _confirma.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final senha = _senha.text;
    if (senha.isEmpty) {
      setState(() => _erro = 'Digite a senha.');
      return;
    }
    await _executar(() => _login(senha));
  }

  Future<void> _definirSenha() async {
    final codigo = _codigo.text.trim();
    final senha = _senha.text;
    if (codigo.isEmpty) {
      setState(() => _erro = 'Digite o código de configuração.');
      return;
    }
    if (senha.length < 10) {
      setState(() => _erro = 'A senha deve ter pelo menos 10 caracteres.');
      return;
    }
    if (senha != _confirma.text) {
      setState(() => _erro = 'As senhas não conferem.');
      return;
    }
    await _executar(() async {
      await api.call('setup', {'codigo': codigo, 'senha': senha});
      await _login(senha);
    });
  }

  Future<void> _login(String senha) async {
    final data = await api.call('login', {'senha': senha}) as Map<String, dynamic>;
    api.token = data['token'] as String;
  }

  Future<void> _executar(Future<void> Function() acao) async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      await acao();
      if (!mounted) return;
      _senha.clear();
      _confirma.clear();
      _codigo.clear();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) setState(() => _erro = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.eco, size: 56, color: tema.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('Nutri App',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.headlineMedium),
                  const SizedBox(height: 32),
                  if (_primeiroAcesso) ...[
                    TextField(
                      controller: _codigo,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'Código de configuração',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _senha,
                    enabled: !_loading,
                    obscureText: !_ver,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _primeiroAcesso ? null : _entrar(),
                    decoration: InputDecoration(
                      labelText: _primeiroAcesso ? 'Nova senha' : 'Senha',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _ver = !_ver),
                      ),
                    ),
                  ),
                  if (_primeiroAcesso) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirma,
                      enabled: !_loading,
                      obscureText: !_ver,
                      onSubmitted: (_) => _definirSenha(),
                      decoration: const InputDecoration(
                        labelText: 'Repita a nova senha',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_erro != null) ...[
                    const SizedBox(height: 16),
                    Text(_erro!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tema.colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading
                        ? null
                        : (_primeiroAcesso ? _definirSenha : _entrar),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_primeiroAcesso ? 'Definir senha e entrar' : 'Entrar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _primeiroAcesso = !_primeiroAcesso;
                              _erro = null;
                            }),
                    child: Text(_primeiroAcesso ? 'Voltar ao login' : 'Primeiro acesso'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
