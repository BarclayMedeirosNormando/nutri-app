import 'package:flutter/material.dart';

import '../models/paciente.dart';
import '../models/plano.dart';
import '../services/plano_service.dart';
import '../utils/datas.dart';
import '../utils/friendly_error.dart';
import '../utils/numeros.dart';
import '../utils/session.dart';

/// Planos alimentares de um paciente.
class PlanosScreen extends StatefulWidget {
  const PlanosScreen({super.key, required this.paciente});

  final Paciente paciente;

  @override
  State<PlanosScreen> createState() => _PlanosScreenState();
}

class _PlanosScreenState extends State<PlanosScreen> {
  List<Plano> _planos = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await PlanoService.listar(widget.paciente.id);
      if (!mounted) return;
      setState(() => _planos = lista);
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

  void _avisar(Object e) {
    if (sessaoExpirada(e)) {
      irParaLogin(context);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }

  Future<void> _novo() async {
    final base = await showDialog<Plano>(
      context: context,
      builder: (_) => _NovoPlanoDialog(pacienteId: widget.paciente.id),
    );
    if (base == null || !mounted) return;
    try {
      final salvo = await PlanoService.salvar(base);
      if (!mounted) return;
      salvo.totalRefeicoes = salvo.refeicoes.length;
      setState(() => _planos.insert(0, salvo));
    } catch (e) {
      if (mounted) _avisar(e);
    }
  }

  Future<void> _apagar(Plano p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar plano?'),
        content: Text('O plano "${p.nome}" será apagado de forma definitiva.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await PlanoService.apagar(p.id);
      if (!mounted) return;
      setState(() => _planos.removeWhere((x) => x.id == p.id));
    } catch (e) {
      if (mounted) _avisar(e);
    }
  }

  String _resumo(Plano p) {
    final partes = <String>[];
    final ini = isoParaBr(p.dataInicio);
    final fim = isoParaBr(p.dataFim);
    if (ini.isNotEmpty && fim.isNotEmpty) {
      partes.add('$ini a $fim');
    } else if (ini.isNotEmpty) {
      partes.add('desde $ini');
    } else if (fim.isNotEmpty) {
      partes.add('até $fim');
    }
    if (p.metaKcal != null) partes.add('meta ${p.metaKcal!.round()} kcal');
    partes.add(p.totalRefeicoes == 1
        ? '1 refeição'
        : '${p.totalRefeicoes} refeições');
    return partes.join(' • ');
  }

  Widget _corpo() {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) {
      return Center(
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
    }
    if (_planos.isEmpty) {
      return const Center(child: Text('Nenhum plano alimentar ainda.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _planos.length,
      itemBuilder: (context, i) {
        final p = _planos[i];
        return ListTile(
          title: Text(p.nome),
          subtitle: Text(_resumo(p)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Chip(
                label: Text(rotuloStatusPlano[p.status] ?? p.status),
                visualDensity: VisualDensity.compact,
              ),
              if (p.status == 'rascunho')
                PopupMenuButton<String>(
                  tooltip: 'Mais opções',
                  onSelected: (_) => _apagar(p),
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(value: 'apagar', child: Text('Apagar')),
                  ],
                ),
            ],
          ),
          onTap: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                content: Text('O editor do plano chega na próxima etapa.'),
              ));
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Planos de ${widget.paciente.nome}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _carregando ? null : _carregar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novo,
        icon: const Icon(Icons.add),
        label: const Text('Novo plano'),
      ),
      body: _corpo(),
    );
  }
}

class _NovoPlanoDialog extends StatefulWidget {
  const _NovoPlanoDialog({required this.pacienteId});

  final String pacienteId;

  @override
  State<_NovoPlanoDialog> createState() => _NovoPlanoDialogState();
}

class _NovoPlanoDialogState extends State<_NovoPlanoDialog> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _meta = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _meta.dispose();
    super.dispose();
  }

  void _criar() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(Plano(
      pacienteId: widget.pacienteId,
      nome: _nome.text.trim(),
      metaKcal: paraDouble(_meta.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo plano alimentar'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nome,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Nome do plano *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _meta,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Meta de calorias (kcal)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = paraDouble(v);
                if (n == null) return 'Número inválido';
                if (n < 0 || n > 10000) return 'Entre 0 e 10000';
                return null;
              },
              onFieldSubmitted: (_) => _criar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _criar, child: const Text('Criar')),
      ],
    );
  }
}
