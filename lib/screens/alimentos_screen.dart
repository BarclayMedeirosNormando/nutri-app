import 'package:flutter/material.dart';

import '../models/alimento.dart';
import '../services/alimento_repositorio.dart';
import '../utils/datas.dart';
import '../utils/friendly_error.dart';
import '../utils/session.dart';
import '../utils/texto.dart';

/// Busca na tabela de alimentos, com calculadora de porção por gramas.
class AlimentosScreen extends StatefulWidget {
  const AlimentosScreen({super.key});

  @override
  State<AlimentosScreen> createState() => _AlimentosScreenState();
}

class _AlimentosScreenState extends State<AlimentosScreen> {
  static const _limiteExibido = 150;
  final _repo = AlimentoRepositorio.instancia;

  List<Alimento> _todos = [];
  bool _carregando = true;
  String? _erro;
  String _busca = '';
  String? _categoria;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar({bool forcar = false}) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await _repo.carregar(forcar: forcar);
      if (!mounted) return;
      setState(() => _todos = lista);
    } catch (e) {
      if (!mounted) return;
      if (sessaoExpirada(e)) {
        irParaLogin(context);
        return;
      }
      setState(() {
        _erro = friendlyError(e);
        _todos = _repo.lista;
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<String> get _categorias {
    final s = _todos.map((a) => a.categoria).where((c) => c.isNotEmpty).toSet();
    return s.toList()..sort();
  }

  List<Alimento> get _filtrados {
    final palavras = semAcento(_busca.trim())
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    return _todos.where((a) {
      if (_categoria != null && a.categoria != _categoria) return false;
      return palavras.every(a.nomeNormalizado.contains);
    }).toList();
  }

  void _detalhe(Alimento a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _DetalheAlimento(alimento: a),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itens = _filtrados;
    final atualizado = _repo.atualizadoEm;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alimentos'),
        actions: [
          IconButton(
            tooltip: 'Atualizar tabela',
            icon: const Icon(Icons.refresh),
            onPressed: _carregando ? null : () => _carregar(forcar: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar alimento (ex.: arroz cozido)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busca = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String?>(
              initialValue: _categoria,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todas as categorias'),
                ),
                for (final c in _categorias)
                  DropdownMenuItem<String?>(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _categoria = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _carregando
                    ? 'Carregando...'
                    : '${itens.length} alimento(s)'
                        '${itens.length > _limiteExibido ? ' (mostrando os $_limiteExibido primeiros)' : ''}'
                        '${atualizado != null ? ' • tabela de ${dataDeTimestamp(atualizado.toUtc().toIso8601String())}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _erro!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _carregando && _todos.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : itens.isEmpty
                    ? const Center(child: Text('Nenhum alimento encontrado.'))
                    : ListView.builder(
                        itemCount: itens.length > _limiteExibido
                            ? _limiteExibido
                            : itens.length,
                        itemBuilder: (context, i) {
                          final a = itens[i];
                          return ListTile(
                            title: Text(a.nome),
                            subtitle: Text(a.categoria),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (a.incompleto)
                                  const Tooltip(
                                    message: 'Dados incompletos na fonte',
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Icon(Icons.warning_amber,
                                          color: Colors.orange),
                                    ),
                                  ),
                                Text(a.energiaKcal == null
                                    ? '— kcal'
                                    : '${a.energiaKcal!.round()} kcal'),
                              ],
                            ),
                            onTap: () => _detalhe(a),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _DetalheAlimento extends StatefulWidget {
  const _DetalheAlimento({required this.alimento});

  final Alimento alimento;

  @override
  State<_DetalheAlimento> createState() => _DetalheAlimentoState();
}

class _DetalheAlimentoState extends State<_DetalheAlimento> {
  final _gramas = TextEditingController(text: '100');

  @override
  void dispose() {
    _gramas.dispose();
    super.dispose();
  }

  double get _g => double.tryParse(_gramas.text.replaceAll(',', '.')) ?? 0;

  String _fmt(double? por100, {int casas = 1}) {
    if (por100 == null) return '—';
    return (por100 * _g / 100).toStringAsFixed(casas).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alimento;
    final tema = Theme.of(context);

    Widget linha(String rotulo, String valor, String unidade) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(rotulo)),
              Text('$valor $unidade',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.nome, style: tema.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${a.categoria} • ${a.origem}',
                style: tema.textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: _gramas,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantidade (g)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            linha('Energia', _fmt(a.energiaKcal, casas: 0), 'kcal'),
            linha('Proteína', _fmt(a.proteinaG), 'g'),
            linha('Lipídios', _fmt(a.lipidiosG), 'g'),
            linha('Carboidrato', _fmt(a.carboidratoG), 'g'),
            linha('Fibra alimentar', _fmt(a.fibraG), 'g'),
            linha('Sódio', _fmt(a.sodioMg, casas: 0), 'mg'),
            if (a.incompleto) ...[
              const SizedBox(height: 12),
              Text(
                'Esta tabela não traz todos os valores deste alimento. '
                'Campos com "—" contam como zero nos cálculos.',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: Colors.orange.shade800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
