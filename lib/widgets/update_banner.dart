import 'dart:async';

import 'package:flutter/material.dart';

import '../services/update_checker.dart';

/// Envolve o app e mostra uma faixa quando há uma nova versão publicada.
/// Verifica ao abrir, ao voltar para o app e a cada 10 minutos.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with WidgetsBindingObserver {
  final _checker = UpdateChecker();
  Timer? _inicial;
  Timer? _periodico;
  bool _novaVersao = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicial = Timer(const Duration(seconds: 3), _verificar);
    _periodico = Timer.periodic(const Duration(minutes: 10), (_) => _verificar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inicial?.cancel();
    _periodico?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verificar();
  }

  Future<void> _verificar() async {
    if (_novaVersao) return;
    final tem = await _checker.hasUpdate();
    if (tem && mounted) setState(() => _novaVersao = true);
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_novaVersao)
          Material(
            color: cores.primaryContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.system_update, color: cores.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nova versão disponível',
                        style: TextStyle(color: cores.onPrimaryContainer),
                      ),
                    ),
                    TextButton(
                      onPressed: _checker.reload,
                      child: const Text('Atualizar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
