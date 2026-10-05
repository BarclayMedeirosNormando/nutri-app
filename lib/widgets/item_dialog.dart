import 'package:flutter/material.dart';

import '../models/alimento.dart';
import '../models/plano.dart';
import '../services/plano_service.dart';
import '../utils/calculo_nutricional.dart';
import '../utils/formato.dart';
import '../utils/friendly_error.dart';
import '../utils/numeros.dart';

/// Diálogo de quantidade de um alimento. Devolve o item pronto (com gramas
/// calculadas) ou null se cancelado. [medidas] é a lista compartilhada de
/// medidas caseiras: as que forem criadas aqui são adicionadas a ela.
Future<ItemRefeicao?> editarItem(
  BuildContext context, {
  required Alimento alimento,
  ItemRefeicao? item,
  required List<MedidaCaseira> medidas,
}) {
  return showDialog<ItemRefeicao>(
    context: context,
    builder: (_) =>
        _ItemDialog(alimento: alimento, item: item, medidas: medidas),
  );
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({
    required this.alimento,
    required this.item,
    required this.medidas,
  });

  final Alimento alimento;
  final ItemRefeicao? item;
  final List<MedidaCaseira> medidas;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final TextEditingController _qtd;
  late final TextEditingController _obs;
  late String _medidaId;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _medidaId = it?.medidaCaseiraId ?? '';
    _qtd = TextEditingController(text: it == null ? '100' : fmtCampo(it.quantidade));
    _obs = TextEditingController(text: it?.observacoes ?? '');
  }

  @override
  void dispose() {
    _qtd.dispose();
    _obs.dispose();
    super.dispose();
  }

  List<MedidaCaseira> get _doAlimento =>
      widget.medidas.where((m) => m.alimentoId == widget.alimento.id).toList();

  MedidaCaseira? get _medida {
    if (_medidaId.isEmpty) return null;
    for (final m in _doAlimento) {
      if (m.id == _medidaId) return m;
    }
    return null;
  }

  ItemRefeicao? _montar() {
    final q = paraDouble(_qtd.text);
    if (q == null || q <= 0 || q > 5000) return null;
    final m = _medida;
    final novo = ItemRefeicao(
      id: widget.item?.id ?? '',
      alimentoId: widget.alimento.id,
      medidaCaseiraId: m?.id ?? '',
      quantidade: q,
      observacoes: _obs.text.trim(),
    );
    novo.recalcularGramas(m);
    if (novo.gramas <= 0 || novo.gramas > 5000) return null;
    return novo;
  }

  void _trocarUnidade(String? id) {
    final novo = id ?? '';
    setState(() {
      final q = paraDouble(_qtd.text);
      if (_medidaId.isEmpty && novo.isNotEmpty && q == 100) _qtd.text = '1';
      if (_medidaId.isNotEmpty && novo.isEmpty && q == 1) _qtd.text = '100';
      _medidaId = novo;
    });
  }

  Future<void> _novaMedida() async {
    final m = await showDialog<MedidaCaseira>(
      context: context,
      builder: (_) => _NovaMedidaDialog(alimento: widget.alimento),
    );
    if (m == null || !mounted) return;
    widget.medidas.add(m);
    _trocarUnidade(m.id);
  }

  Widget _preview(ThemeData tema) {
    final p = _montar();
    if (p == null) {
      return Text(
        'Informe uma quantidade válida.',
        style: TextStyle(color: tema.colorScheme.error),
      );
    }
    final t = totaisItem(p, widget.alimento);
    return Text(
      '= ${fmtG(p.gramas)} g  •  ${fmtNum(t.kcal, 0)} kcal  •  '
      'P ${fmtNum(t.proteina)} g  •  C ${fmtNum(t.carboidrato)} g  •  '
      'L ${fmtNum(t.lipidios)} g',
      style: tema.textTheme.bodyMedium,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final medidas = _doAlimento;
    final valor = medidas.any((m) => m.id == _medidaId) ? _medidaId : '';
    final pronto = _montar();

    return AlertDialog(
      title: Text(widget.alimento.nome, maxLines: 3, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtd,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('un-$valor-${medidas.length}'),
                      initialValue: valor,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Unidade',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Gramas (g)'),
                        ),
                        for (final m in medidas)
                          DropdownMenuItem<String>(
                            value: m.id,
                            child: Text(
                              '${m.descricao} (${fmtG(m.gramas)} g)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _trocarUnidade,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _novaMedida,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova medida caseira'),
                ),
              ),
              _preview(tema),
              const SizedBox(height: 12),
              TextField(
                controller: _obs,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (widget.alimento.incompleto)
                Text(
                  'A tabela não traz todos os valores deste alimento; '
                  'os ausentes contam como zero.',
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: Colors.orange.shade800),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: pronto == null ? null : () => Navigator.of(context).pop(pronto),
          child: Text(widget.item == null ? 'Adicionar' : 'Salvar'),
        ),
      ],
    );
  }
}

class _NovaMedidaDialog extends StatefulWidget {
  const _NovaMedidaDialog({required this.alimento});

  final Alimento alimento;

  @override
  State<_NovaMedidaDialog> createState() => _NovaMedidaDialogState();
}

class _NovaMedidaDialogState extends State<_NovaMedidaDialog> {
  final _desc = TextEditingController();
  final _gramas = TextEditingController();
  bool _ocupado = false;
  String? _erro;

  @override
  void dispose() {
    _desc.dispose();
    _gramas.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final desc = _desc.text.trim();
    final g = paraDouble(_gramas.text);
    if (desc.isEmpty) {
      setState(() => _erro = 'Informe a descrição (ex.: Colher de sopa).');
      return;
    }
    if (g == null || g < 0.1 || g > 5000) {
      setState(() => _erro = 'Informe as gramas (entre 0,1 e 5000).');
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final m = await MedidaService.salvar(MedidaCaseira(
        id: '',
        alimentoId: widget.alimento.id,
        descricao: desc,
        gramas: g,
      ));
      if (!mounted) return;
      Navigator.of(context).pop(m);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = friendlyError(e);
        _ocupado = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova medida caseira'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.alimento.nome,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Descrição (ex.: Colher de sopa)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _gramas,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Equivale a quantos gramas?',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _ocupado ? null : _salvar(),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _ocupado ? null : _salvar,
          child: const Text('Salvar medida'),
        ),
      ],
    );
  }
}
