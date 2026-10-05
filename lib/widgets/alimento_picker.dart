import 'package:flutter/material.dart';

import '../models/alimento.dart';
import '../utils/texto.dart';

/// Diálogo de busca de alimento (todas as palavras digitadas, sem acento).
Future<Alimento?> escolherAlimento(BuildContext context, List<Alimento> todos) {
  return showDialog<Alimento>(
    context: context,
    builder: (_) => _AlimentoPicker(todos: todos),
  );
}

class _AlimentoPicker extends StatefulWidget {
  const _AlimentoPicker({required this.todos});

  final List<Alimento> todos;

  @override
  State<_AlimentoPicker> createState() => _AlimentoPickerState();
}

class _AlimentoPickerState extends State<_AlimentoPicker> {
  static const _limite = 100;
  String _busca = '';

  List<Alimento> get _filtrados {
    final palavras = semAcento(_busca.trim())
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    return widget.todos
        .where((a) => palavras.every(a.nomeNormalizado.contains))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final itens = _filtrados;
    final mostrar = itens.length > _limite ? _limite : itens.length;
    return Dialog(
      child: SizedBox(
        width: 560,
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${itens.length} alimento(s)'
                  '${itens.length > _limite ? ' (mostrando os $_limite primeiros)' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Expanded(
              child: itens.isEmpty
                  ? const Center(child: Text('Nenhum alimento encontrado.'))
                  : ListView.builder(
                      itemCount: mostrar,
                      itemBuilder: (context, i) {
                        final a = itens[i];
                        return ListTile(
                          dense: true,
                          title: Text(a.nome),
                          subtitle: Text(
                            a.origem == 'PROPRIO'
                                ? '${a.categoria} • cadastrado por você'
                                : a.categoria,
                          ),
                          trailing: Text(a.energiaKcal == null
                              ? '— kcal'
                              : '${a.energiaKcal!.round()} kcal'),
                          onTap: () => Navigator.of(context).pop(a),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
