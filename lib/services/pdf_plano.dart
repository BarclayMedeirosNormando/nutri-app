import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/alimento.dart';
import '../models/config_profissional.dart';
import '../models/plano.dart';
import '../utils/calculo_nutricional.dart';
import '../utils/datas.dart';
import '../utils/formato.dart';
import '../utils/texto.dart';

// Fontes padrão do PDF cobrem o português (Latin-1); por isso o texto evita
// símbolos fora dessa faixa (sem marcadores "•", travessões longos etc.).

const _cor = PdfColors.teal800;
const _cinza = PdfColors.grey700;

String _slug(String s) => semAcento(s)
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Nome do arquivo baixado, ex.: plano-fulana-de-tal-plano-1800-kcal.pdf
String nomeArquivoPdf(Plano plano, String nomePaciente) {
  final partes =
      [_slug(nomePaciente), _slug(plano.nome)].where((s) => s.isNotEmpty);
  return 'plano-${partes.isEmpty ? 'alimentar' : partes.join('-')}.pdf';
}

pw.TextStyle _est({
  double tam = 10,
  bool negrito = false,
  bool italico = false,
  PdfColor? cor,
}) =>
    pw.TextStyle(
      fontSize: tam,
      fontWeight: negrito ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontStyle: italico ? pw.FontStyle.italic : pw.FontStyle.normal,
      color: cor,
    );

pw.Widget _cabecalho(ConfigProfissional c) {
  final detalhes = [
    if (c.crn.isNotEmpty) c.crn,
    if (c.contato.isNotEmpty) c.contato,
  ].join('  -  ');
  if (c.nome.isEmpty && detalhes.isEmpty) return pw.SizedBox();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (c.nome.isNotEmpty)
        pw.Text(c.nome, style: _est(tam: 14, negrito: true, cor: _cor)),
      if (detalhes.isNotEmpty) pw.Text(detalhes, style: _est(cor: _cinza)),
      pw.Divider(color: _cor, thickness: 1),
    ],
  );
}

pw.Widget _celula(pw.Widget child) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: child,
    );

pw.Widget _refeicao(
  Refeicao r,
  Map<String, Alimento> alimentos,
  Map<String, MedidaCaseira> medidas,
) {
  final t = totaisRefeicao(r, alimentos);
  final titulo = r.horario.isEmpty ? r.nome : '${r.horario}  ${r.nome}';

  pw.TableRow linha(ItemRefeicao it) {
    final a = alimentos[it.alimentoId];
    final m = it.medidaCaseiraId.isEmpty ? null : medidas[it.medidaCaseiraId];
    final qtd = m == null
        ? '${fmtG(it.gramas)} g'
        : '${fmtCampo(it.quantidade)} x ${m.descricao} (${fmtG(it.gramas)} g)';
    final kcal = totaisItem(it, a).kcal;
    return pw.TableRow(
      children: [
        _celula(pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(a?.nome ?? 'Alimento', style: _est()),
            if (it.observacoes.isNotEmpty)
              pw.Text(it.observacoes, style: _est(tam: 8, italico: true, cor: _cinza)),
          ],
        )),
        _celula(pw.Text(qtd, style: _est())),
        _celula(pw.Text('${fmtNum(kcal, 0)} kcal',
            style: _est(), textAlign: pw.TextAlign.right)),
      ],
    );
  }

  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          color: PdfColors.grey200,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(titulo, style: _est(tam: 11, negrito: true)),
              pw.Text('${fmtNum(t.kcal, 0)} kcal',
                  style: _est(tam: 11, negrito: true)),
            ],
          ),
        ),
        if (r.itens.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('Sem alimentos.', style: _est(italico: true, cor: _cinza)),
          )
        else
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(1.6),
            },
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
            children: [for (final it in r.itens) linha(it)],
          ),
        if (r.observacoes.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, left: 4),
            child: pw.Text('Obs.: ${r.observacoes}',
                style: _est(tam: 9, italico: true, cor: _cinza)),
          ),
      ],
    ),
  );
}

pw.Widget _totais(Plano p, Totais t) {
  final meta = p.metaKcal;
  final kcal = '${fmtNum(t.kcal, 0)} kcal'
      '${meta != null && meta > 0 ? '  (meta: ${fmtNum(meta, 0)} kcal)' : ''}';
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _cor, width: 1)),
    padding: const pw.EdgeInsets.all(8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Total do dia', style: _est(tam: 12, negrito: true, cor: _cor)),
        pw.SizedBox(height: 4),
        pw.Text(kcal, style: _est(tam: 11, negrito: true)),
        pw.SizedBox(height: 2),
        pw.Text(
          'Proteína: ${fmtNum(t.proteina)} g (${fmtNum(t.pctProteina, 0)}%)   '
          'Carboidrato: ${fmtNum(t.carboidrato)} g (${fmtNum(t.pctCarboidrato, 0)}%)   '
          'Lipídios: ${fmtNum(t.lipidios)} g (${fmtNum(t.pctLipidios, 0)}%)',
          style: _est(),
        ),
        pw.Text(
          'Fibra: ${fmtNum(t.fibra)} g   Sódio: ${fmtNum(t.sodio, 0)} mg',
          style: _est(),
        ),
      ],
    ),
  );
}

/// Gera o PDF do plano para entregar ao paciente.
Future<Uint8List> gerarPdfPlano({
  required Plano plano,
  required String nomePaciente,
  required Map<String, Alimento> alimentos,
  required List<MedidaCaseira> medidas,
  required ConfigProfissional config,
}) async {
  final mapaMedidas = {for (final m in medidas) m.id: m};
  final total = totaisPlano(plano, alimentos);

  final ini = isoParaBr(plano.dataInicio);
  final fim = isoParaBr(plano.dataFim);
  final periodo = ini.isNotEmpty && fim.isNotEmpty
      ? '$ini a $fim'
      : ini.isNotEmpty
          ? 'a partir de $ini'
          : fim.isNotEmpty
              ? 'até $fim'
              : '';
  final hoje = dataDeTimestamp(DateTime.now().toUtc().toIso8601String());

  final doc = pw.Document(
    title: plano.nome,
    author: config.nome.isEmpty ? null : config.nome,
    creator: 'Nutri App',
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Gerado em $hoje', style: _est(tam: 8, cor: _cinza)),
          pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: _est(tam: 8, cor: _cinza)),
        ],
      ),
      build: (ctx) => [
        _cabecalho(config),
        pw.SizedBox(height: 8),
        pw.Text('Plano alimentar', style: _est(tam: 18, negrito: true, cor: _cor)),
        pw.Text(plano.nome, style: _est(tam: 13, negrito: true)),
        pw.SizedBox(height: 4),
        if (nomePaciente.isNotEmpty) pw.Text('Paciente: $nomePaciente', style: _est()),
        if (periodo.isNotEmpty) pw.Text('Período: $periodo', style: _est()),
        pw.SizedBox(height: 12),
        for (final r in plano.refeicoes) _refeicao(r, alimentos, mapaMedidas),
        _totais(plano, total),
        if (plano.observacoes.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Orientações', style: _est(tam: 12, negrito: true, cor: _cor)),
          pw.SizedBox(height: 2),
          pw.Text(plano.observacoes, style: _est()),
        ],
      ],
    ),
  );
  return doc.save();
}
