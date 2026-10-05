import 'package:flutter/material.dart';

import '../utils/calculo_nutricional.dart';
import '../utils/formato.dart';

/// Faixa fixa com os totais do plano (calorias, macros, fibra e sódio).
class TotaisBar extends StatelessWidget {
  const TotaisBar({super.key, required this.totais, this.metaKcal});

  final Totais totais;
  final double? metaKcal;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final meta = metaKcal;
    final pct = (meta != null && meta > 0) ? totais.kcal / meta : null;

    return Material(
      elevation: 1,
      color: tema.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text('${fmtNum(totais.kcal, 0)} kcal',
                    style: tema.textTheme.titleLarge),
                if (meta != null && pct != null)
                  Text('de ${fmtNum(meta, 0)} kcal (${fmtNum(pct * 100, 0)}%)',
                      style: tema.textTheme.bodyMedium),
              ],
            ),
            if (pct != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0).toDouble(),
                ),
              ),
            Text(
              'P ${fmtNum(totais.proteina)} g (${fmtNum(totais.pctProteina, 0)}%)'
              '  •  C ${fmtNum(totais.carboidrato)} g (${fmtNum(totais.pctCarboidrato, 0)}%)'
              '  •  L ${fmtNum(totais.lipidios)} g (${fmtNum(totais.pctLipidios, 0)}%)'
              '  •  Fibra ${fmtNum(totais.fibra)} g'
              '  •  Sódio ${fmtNum(totais.sodio, 0)} mg',
              style: tema.textTheme.bodySmall,
            ),
            if (totais.semDados > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${totais.semDados} item(ns) com dados incompletos na tabela: '
                  'valores ausentes contam como zero.',
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: Colors.orange.shade800),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
