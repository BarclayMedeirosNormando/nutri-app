import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/alimento.dart';
import '../models/plano.dart';
import '../services/alimento_repositorio.dart';
import '../services/plano_service.dart';
import '../utils/calculo_nutricional.dart';
import '../utils/datas.dart';
import '../utils/formato.dart';
import '../utils/friendly_error.dart';
import '../utils/numeros.dart';
import '../utils/session.dart';
import '../widgets/alimento_picker.dart';
import '../widgets/item_dialog.dart';
import '../widgets/totais_bar.dart';

/// Editor do plano alimentar: refeições, alimentos e totais em tempo real.
/// Nada é gravado até tocar em "Salvar"; ao sair com alterações pede confirmação.
class PlanoEditorScreen extends StatefulWidget {
  const PlanoEditorScreen({super.key, required this.planoId});

  final String planoId;

  @override
  State<PlanoEditorScreen> createState() => _PlanoEditorScreenState();
}

class _PlanoEditorScreenState extends State<PlanoEditorScreen> {
  static const _sugestoes = [
    'Café da manhã',
    'Lanche da manhã',
    'Almoço',
    'Lanche da tarde',
    'Jantar',
    'Ceia',
  ];

  Plano? _plano;
  String _jsonSalvo = '';
  List<Alimento> _listaAlimentos = [];
  Map<String, Alimento> _alimentos = {};
  final List<MedidaCaseira> _medidas = [];

  bool _carregando = true;
  bool _salvando = false;
  bool _descartar = false;
  String? _erro;

  final _nome = TextEditingController();
  final _meta = TextEditingController();
  final _ini = TextEditingController();
  final _fim = TextEditingController();
  final _obs = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nome.dispose();
    _meta.dispose();
    _ini.dispose();
    _fim.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final plano = await PlanoService.obter(widget.planoId);
      final alimentos = await AlimentoRepositorio.instancia.carregar();
      final medidas = await MedidaService.listar();
      if (!mounted) return;
      setState(() {
        _plano = plano;
        _listaAlimentos = alimentos;
        _alimentos = indexarAlimentos(alimentos);
        _medidas
          ..clear()
          ..addAll(medidas);
        _jsonSalvo = jsonEncode(plano.toJson());
      });
      _preencherCabecalho(plano);
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

  void _preencherCabecalho(Plano p) {
    _nome.text = p.nome;
    _meta.text = p.metaKcal == null ? '' : fmtCampo(p.metaKcal!);
    _ini.text = isoParaBr(p.dataInicio);
    _fim.text = isoParaBr(p.dataFim);
    _obs.text = p.observacoes;
  }

  /// Copia os campos do cabeçalho para o plano (valores inválidos são
  /// conferidos só ao salvar).
  void _sincronizar() {
    final p = _plano;
    if (p == null) return;
    setState(() {
      p.nome = _nome.text;
      p.metaKcal = paraDouble(_meta.text);
      p.observacoes = _obs.text;
      final i = brParaIsoLivre(_ini.text);
      if (i != null) p.dataInicio = i;
      final f = brParaIsoLivre(_fim.text);
      if (f != null) p.dataFim = f;
    });
  }

  bool get _sujo => _plano != null && jsonEncode(_plano!.toJson()) != _jsonSalvo;

  void _msg(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  void _erroApi(Object e) {
    if (sessaoExpirada(e)) {
      irParaLogin(context);
      return;
    }
    _msg(friendlyError(e));
  }

  Future<void> _salvar() async {
    final p = _plano;
    if (p == null || _salvando) return;
    final ini = brParaIsoLivre(_ini.text);
    final fim = brParaIsoLivre(_fim.text);
    final meta = paraDouble(_meta.text);
    if (_nome.text.trim().isEmpty) {
      _msg('Informe o nome do plano.');
      return;
    }
    if (ini == null) {
      _msg('Data de início inválida (use dd/mm/aaaa).');
      return;
    }
    if (fim == null) {
      _msg('Data de fim inválida (use dd/mm/aaaa).');
      return;
    }
    if (ini.isNotEmpty && fim.isNotEmpty && fim.compareTo(ini) < 0) {
      _msg('A data de fim deve ser igual ou depois da data de início.');
      return;
    }
    if (_meta.text.trim().isNotEmpty && (meta == null || meta < 0 || meta > 10000)) {
      _msg('Meta de calorias inválida (0 a 10000).');
      return;
    }
    p
      ..nome = _nome.text.trim()
      ..dataInicio = ini
      ..dataFim = fim
      ..metaKcal = meta
      ..observacoes = _obs.text.trim();

    setState(() => _salvando = true);
    try {
      final salvo = await PlanoService.salvar(p);
      if (!mounted) return;
      setState(() {
        _plano = salvo;
        _jsonSalvo = jsonEncode(salvo.toJson());
      });
      _preencherCabecalho(salvo);
      _msg('Plano salvo.');
    } catch (e) {
      if (mounted) _erroApi(e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _confirmarSaida() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('Há alterações que ainda não foram salvas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (sair != true || !mounted) return;
    setState(() => _descartar = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  /* ---------- refeições ---------- */

  Future<void> _novaRefeicao() async {
    final r = await showDialog<({String nome, String horario})>(
      context: context,
      builder: (_) => const _RefeicaoDialog(
        titulo: 'Nova refeição',
        sugestoes: _sugestoes,
      ),
    );
    if (r == null || !mounted) return;
    setState(() => _plano!.refeicoes.add(Refeicao(nome: r.nome, horario: r.horario)));
  }

  Future<void> _editarRefeicao(Refeicao ref) async {
    final r = await showDialog<({String nome, String horario})>(
      context: context,
      builder: (_) => _RefeicaoDialog(
        titulo: 'Editar refeição',
        sugestoes: _sugestoes,
        nome: ref.nome,
        horario: ref.horario,
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      ref.nome = r.nome;
      ref.horario = r.horario;
    });
  }

  Future<void> _removerRefeicao(int i) async {
    final ref = _plano!.refeicoes[i];
    if (ref.itens.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remover refeição?'),
          content: Text('"${ref.nome}" e seus ${ref.itens.length} alimento(s) '
              'serão removidos do plano (só vale ao salvar).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remover'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _plano!.refeicoes.removeAt(i));
  }

  void _mover(int i, int delta) {
    final l = _plano!.refeicoes;
    final j = i + delta;
    if (j < 0 || j >= l.length) return;
    setState(() {
      final x = l.removeAt(i);
      l.insert(j, x);
    });
  }

  /* ---------- itens ---------- */

  Future<void> _novoItem(Refeicao ref) async {
    final a = await escolherAlimento(context, _listaAlimentos);
    if (a == null || !mounted) return;
    final it = await editarItem(context, alimento: a, medidas: _medidas);
    if (it == null || !mounted) return;
    setState(() => ref.itens.add(it));
  }

  Future<void> _editarItem(Refeicao ref, int k) async {
    final atual = ref.itens[k];
    final a = _alimentos[atual.alimentoId];
    if (a == null) {
      _msg('Este alimento não está mais na tabela. Remova-o do plano.');
      return;
    }
    final it = await editarItem(
      context,
      alimento: a,
      item: atual,
      medidas: _medidas,
    );
    if (it == null || !mounted) return;
    setState(() => ref.itens[k] = it);
  }

  /* ---------- widgets ---------- */

  Widget _cabecalho(Plano p) {
    return Card(
      child: ExpansionTile(
        title: const Text('Dados do plano'),
        subtitle: Text(rotuloStatusPlano[p.status] ?? p.status),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          TextField(
            controller: _nome,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Nome do plano *',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _sincronizar(),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: statusPlano.contains(p.status) ? p.status : 'rascunho',
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in statusPlano)
                      DropdownMenuItem<String>(
                        value: s,
                        child: Text(rotuloStatusPlano[s] ?? s),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => p.status = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _meta,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Meta (kcal)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _sincronizar(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ini,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Início',
                    hintText: 'dd/mm/aaaa',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _sincronizar(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _fim,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Fim',
                    hintText: 'dd/mm/aaaa',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _sincronizar(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obs,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Observações',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _sincronizar(),
          ),
        ],
      ),
    );
  }

  Widget _linhaItem(Refeicao r, int k) {
    final it = r.itens[k];
    final a = _alimentos[it.alimentoId];
    final t = totaisItem(it, a);
    final m = it.medidaCaseiraId.isEmpty
        ? null
        : _medidas.where((x) => x.id == it.medidaCaseiraId).firstOrNull;
    final qtd = m == null
        ? '${fmtG(it.gramas)} g'
        : '${fmtCampo(it.quantidade)} × ${m.descricao} (${fmtG(it.gramas)} g)';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 8),
      leading: (a == null || a.incompleto)
          ? const Tooltip(
              message: 'Dados incompletos ou alimento não encontrado',
              child: Icon(Icons.warning_amber, color: Colors.orange),
            )
          : null,
      title: Text(a?.nome ?? 'Alimento não encontrado', maxLines: 2),
      subtitle: Text('$qtd  •  ${fmtNum(t.kcal, 0)} kcal'),
      trailing: IconButton(
        tooltip: 'Remover alimento',
        icon: const Icon(Icons.close),
        onPressed: () => setState(() => r.itens.removeAt(k)),
      ),
      onTap: () => _editarItem(r, k),
    );
  }

  Widget _cardRefeicao(Plano p, int i) {
    final r = p.refeicoes[i];
    final t = totaisRefeicao(r, _alimentos);
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                r.horario.isEmpty ? r.nome : '${r.horario}  •  ${r.nome}',
                style: tema.textTheme.titleMedium,
              ),
              subtitle: Text(
                '${fmtNum(t.kcal, 0)} kcal  •  P ${fmtNum(t.proteina)} g  •  '
                'C ${fmtNum(t.carboidrato)} g  •  L ${fmtNum(t.lipidios)} g',
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'Opções da refeição',
                onSelected: (v) {
                  switch (v) {
                    case 'editar':
                      _editarRefeicao(r);
                    case 'subir':
                      _mover(i, -1);
                    case 'descer':
                      _mover(i, 1);
                    case 'remover':
                      _removerRefeicao(i);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem<String>(
                      value: 'editar', child: Text('Editar nome e horário')),
                  PopupMenuItem<String>(
                      value: 'subir', enabled: i > 0, child: const Text('Mover para cima')),
                  PopupMenuItem<String>(
                      value: 'descer',
                      enabled: i < p.refeicoes.length - 1,
                      child: const Text('Mover para baixo')),
                  const PopupMenuItem<String>(
                      value: 'remover', child: Text('Remover refeição')),
                ],
              ),
            ),
            for (var k = 0; k < r.itens.length; k++) _linhaItem(r, k),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton.icon(
                onPressed: () => _novoItem(r),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar alimento'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corpo(Plano p) {
    return Column(
      children: [
        TotaisBar(totais: totaisPlano(p, _alimentos), metaKcal: p.metaKcal),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  _cabecalho(p),
                  const SizedBox(height: 12),
                  if (p.refeicoes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Nenhuma refeição ainda.')),
                    ),
                  for (var i = 0; i < p.refeicoes.length; i++) _cardRefeicao(p, i),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _novaRefeicao,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar refeição'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _plano;
    final sujo = _sujo;
    Widget corpo;
    if (_carregando) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (_erro != null || p == null) {
      corpo = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_erro ?? 'Plano não carregado.', textAlign: TextAlign.center),
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
      corpo = _corpo(p);
    }

    return PopScope(
      canPop: !sujo || _descartar,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSaida();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            (p != null && p.nome.isNotEmpty) ? p.nome : 'Plano alimentar',
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: (sujo && !_salvando) ? _salvar : null,
                icon: _salvando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Salvar'),
              ),
            ),
          ],
        ),
        body: corpo,
      ),
    );
  }
}

class _RefeicaoDialog extends StatefulWidget {
  const _RefeicaoDialog({
    required this.titulo,
    required this.sugestoes,
    this.nome = '',
    this.horario = '',
  });

  final String titulo;
  final List<String> sugestoes;
  final String nome;
  final String horario;

  @override
  State<_RefeicaoDialog> createState() => _RefeicaoDialogState();
}

class _RefeicaoDialogState extends State<_RefeicaoDialog> {
  late final TextEditingController _nome;
  late String _horario;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.nome);
    _horario = widget.horario;
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _escolherHora() async {
    var inicial = const TimeOfDay(hour: 8, minute: 0);
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(_horario);
    if (m != null) {
      inicial = TimeOfDay(hour: int.parse(m[1]!), minute: int.parse(m[2]!));
    }
    final t = await showTimePicker(
      context: context,
      initialTime: inicial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null || !mounted) return;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    setState(() => _horario = '$hh:$mm');
  }

  @override
  Widget build(BuildContext context) {
    final nome = _nome.text.trim();
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nome,
                autofocus: true,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Nome da refeição *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in widget.sugestoes)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => setState(() => _nome.text = s),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _escolherHora,
                    icon: const Icon(Icons.schedule),
                    label: Text(_horario.isEmpty
                        ? 'Definir horário'
                        : 'Horário: $_horario'),
                  ),
                  if (_horario.isNotEmpty)
                    IconButton(
                      tooltip: 'Sem horário',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _horario = ''),
                    ),
                ],
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
          onPressed: nome.isEmpty
              ? null
              : () => Navigator.of(context).pop((nome: nome, horario: _horario)),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
