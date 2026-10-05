import 'package:flutter/material.dart';

import '../models/paciente.dart';
import '../services/paciente_service.dart';
import '../utils/datas.dart';
import '../utils/friendly_error.dart';
import '../utils/session.dart';
import '../widgets/paciente_form.dart';
import 'alimentos_screen.dart';
import 'planos_screen.dart';

/// Lista de pacientes. Em tela larga (computador/tablet) mostra a lista e o
/// formulário lado a lado; no celular o formulário abre em tela cheia.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _larguraDuasColunas = 900.0;

  List<Paciente> _todos = [];
  bool _carregando = true;
  bool _arquivados = false;
  bool _novo = false;
  String? _erro;
  String _busca = '';
  Paciente? _selecionado;

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
      final lista =
          await PacienteService.listar(incluirArquivados: _arquivados);
      if (!mounted) return;
      setState(() => _todos = lista);
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

  List<Paciente> get _filtrados {
    final q = _busca.trim().toLowerCase();
    if (q.isEmpty) return _todos;
    return _todos
        .where((p) =>
            p.nome.toLowerCase().contains(q) || p.telefone.contains(q))
        .toList();
  }

  void _aoSalvar(Paciente s) {
    setState(() {
      final i = _todos.indexWhere((x) => x.id == s.id);
      if (i >= 0) {
        _todos[i] = s;
      } else {
        _todos.add(s);
      }
      if (!s.ativo && !_arquivados) {
        _todos.removeWhere((x) => x.id == s.id);
        _selecionado = null;
      } else {
        _selecionado = s;
      }
      _novo = false;
      _todos.sort(
          (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    });
  }

  Future<void> _abrir(Paciente? p, {required bool largo}) async {
    if (largo) {
      setState(() {
        _selecionado = p;
        _novo = p == null;
      });
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: Text(p?.nome ?? 'Novo paciente')),
          body: PacienteForm(
            paciente: p,
            onSalvo: (s) {
              _aoSalvar(s);
              Navigator.of(ctx).pop();
            },
          ),
        ),
      ),
    );
  }

  Widget _lista({required bool largo}) {
    final itens = _filtrados;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por nome ou telefone',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _busca = v),
          ),
        ),
        SwitchListTile(
          dense: true,
          title: const Text('Mostrar arquivados'),
          value: _arquivados,
          onChanged: (v) {
            setState(() => _arquivados = v);
            _carregar();
          },
        ),
        Expanded(child: _corpoLista(itens, largo)),
      ],
    );
  }

  Widget _corpoLista(List<Paciente> itens, bool largo) {
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
    if (itens.isEmpty) {
      return Center(
        child: Text(_todos.isEmpty
            ? 'Nenhum paciente cadastrado.'
            : 'Nenhum paciente encontrado.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: itens.length,
      itemBuilder: (context, i) {
        final p = itens[i];
        final idade = idadeDe(p.dataNascimento);
        final detalhe = [
          if (idade != null) '$idade anos',
          if (p.objetivo.isNotEmpty) p.objetivo,
        ].join(' • ');
        return ListTile(
          selected: largo && !_novo && _selecionado?.id == p.id,
          leading: CircleAvatar(
            child: Text(p.nome.isEmpty ? '?' : p.nome[0].toUpperCase()),
          ),
          title: Text(p.nome),
          subtitle: detalhe.isEmpty ? null : Text(detalhe, maxLines: 1),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Planos alimentares',
                icon: const Icon(Icons.assignment_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlanosScreen(paciente: p),
                  ),
                ),
              ),
              if (!p.ativo)
                Text('Arquivado', style: Theme.of(context).textTheme.bodySmall),
              if (!p.temConsentimento)
                const Tooltip(
                  message: 'Consentimento LGPD não registrado',
                  child: Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.gpp_maybe, color: Colors.orange),
                  ),
                ),
            ],
          ),
          onTap: () => _abrir(p, largo: largo),
        );
      },
    );
  }

  Widget _detalhe() {
    if (_novo) {
      return PacienteForm(key: const ValueKey('novo'), onSalvo: _aoSalvar);
    }
    final s = _selecionado;
    if (s != null) {
      return PacienteForm(key: ValueKey(s.id), paciente: s, onSalvo: _aoSalvar);
    }
    return const Center(child: Text('Selecione ou cadastre um paciente.'));
  }

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= _larguraDuasColunas;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pacientes'),
        actions: [
          IconButton(
            tooltip: 'Alimentos',
            icon: const Icon(Icons.restaurant_menu),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AlimentosScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _carregando ? null : _carregar,
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => irParaLogin(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(null, largo: largo),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo paciente'),
      ),
      body: largo
          ? Row(
              children: [
                SizedBox(width: 380, child: _lista(largo: true)),
                const VerticalDivider(width: 1),
                Expanded(child: _detalhe()),
              ],
            )
          : _lista(largo: false),
    );
  }
}
