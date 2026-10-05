import 'package:flutter/material.dart';

import '../models/config_profissional.dart';
import '../services/config_service.dart';
import '../utils/friendly_error.dart';
import '../utils/session.dart';

/// Dados da profissional que saem no cabeçalho do PDF do plano.
class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  final _nome = TextEditingController();
  final _crn = TextEditingController();
  final _contato = TextEditingController();

  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nome.dispose();
    _crn.dispose();
    _contato.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final c = await ConfigService.obter();
      if (!mounted) return;
      _nome.text = c.nome;
      _crn.text = c.crn;
      _contato.text = c.contato;
    } catch (e) {
      if (!mounted) return;
      if (sessaoExpirada(e)) {
        irParaLogin(context);
        return;
      }
      setState(() => _erro = friendlyError(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await ConfigService.salvar(ConfigProfissional(
        nome: _nome.text.trim(),
        crn: _crn.text.trim(),
        contato: _contato.text.trim(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Configurações salvas.')));
    } catch (e) {
      if (!mounted) return;
      if (sessaoExpirada(e)) {
        irParaLogin(context);
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget corpo;
    if (_carregando) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (_erro != null) {
      corpo = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_erro!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _carregar,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    } else {
      corpo = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Estes dados aparecem no cabeçalho do PDF do plano alimentar.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nome,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Nome da profissional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _crn,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'CRN',
                  hintText: 'Ex.: CRN-6 00000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contato,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Contato (telefone, e-mail ou Instagram)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: corpo,
    );
  }
}
