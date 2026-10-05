import 'package:flutter/material.dart';

import '../models/paciente.dart';
import '../services/paciente_service.dart';
import '../utils/datas.dart';
import '../utils/friendly_error.dart';
import '../utils/session.dart';

/// Formulário de cadastro/edição de paciente. Usado ao lado da lista (tela larga)
/// ou em tela cheia (celular). [onSalvo] recebe o paciente já gravado no servidor.
class PacienteForm extends StatefulWidget {
  const PacienteForm({super.key, this.paciente, required this.onSalvo});

  final Paciente? paciente;
  final ValueChanged<Paciente> onSalvo;

  @override
  State<PacienteForm> createState() => _PacienteFormState();
}

class _PacienteFormState extends State<PacienteForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _nasc;
  late final TextEditingController _tel;
  late final TextEditingController _email;
  late final TextEditingController _objetivo;
  late final TextEditingController _obs;
  late String _sexo;

  bool _consentimento = false;
  bool _ocupado = false;
  String? _erro;

  bool get _existente => widget.paciente != null;

  @override
  void initState() {
    super.initState();
    final p = widget.paciente ?? const Paciente();
    _nome = TextEditingController(text: p.nome);
    _nasc = TextEditingController(text: isoParaBr(p.dataNascimento));
    _tel = TextEditingController(text: p.telefone);
    _email = TextEditingController(text: p.email);
    _objetivo = TextEditingController(text: p.objetivo);
    _obs = TextEditingController(text: p.observacoes);
    _sexo = p.sexo;
  }

  @override
  void dispose() {
    _nome.dispose();
    _nasc.dispose();
    _tel.dispose();
    _email.dispose();
    _objetivo.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final p = Paciente(
        id: widget.paciente?.id ?? '',
        nome: _nome.text.trim(),
        dataNascimento: brParaIso(_nasc.text) ?? '',
        sexo: _sexo,
        telefone: _tel.text.trim(),
        email: _email.text.trim(),
        objetivo: _objetivo.text.trim(),
        observacoes: _obs.text.trim(),
        ativo: widget.paciente?.ativo ?? true,
      );
      final salvo =
          await PacienteService.salvar(p, consentimento: _consentimento);
      if (!mounted) return;
      final aviso = ScaffoldMessenger.of(context);
      widget.onSalvo(salvo);
      aviso.showSnackBar(const SnackBar(content: Text('Paciente salvo.')));
    } catch (e) {
      if (!mounted) return;
      if (sessaoExpirada(e)) {
        irParaLogin(context);
        return;
      }
      setState(() => _erro = friendlyError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _alternarArquivo() async {
    final p = widget.paciente!;
    final arquivar = p.ativo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(arquivar ? 'Arquivar paciente?' : 'Reativar paciente?'),
        content: Text(arquivar
            ? 'Ele sai da lista principal, mas todos os dados são mantidos.'
            : 'Ele volta para a lista principal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(arquivar ? 'Arquivar' : 'Reativar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final atualizado = await PacienteService.arquivar(p.id, arquivar);
      if (!mounted) return;
      widget.onSalvo(atualizado);
    } catch (e) {
      if (!mounted) return;
      if (sessaoExpirada(e)) {
        irParaLogin(context);
        return;
      }
      setState(() => _erro = friendlyError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  InputDecoration _dec(String rotulo, {String? dica}) => InputDecoration(
        labelText: rotulo,
        hintText: dica,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final p = widget.paciente;

    return Form(
      key: _form,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _existente ? p!.nome : 'Novo paciente',
                      style: tema.textTheme.titleLarge,
                    ),
                  ),
                  if (_existente && !p!.ativo) const Chip(label: Text('Arquivado')),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nome,
                enabled: !_ocupado,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Nome completo *'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe o nome.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nasc,
                enabled: !_ocupado,
                keyboardType: TextInputType.datetime,
                decoration: _dec('Data de nascimento', dica: 'dd/mm/aaaa'),
                validator: (v) => brParaIso(v ?? '') == null
                    ? 'Data inválida (use dd/mm/aaaa).'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _sexo,
                decoration: _dec('Sexo'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Não informado')),
                  DropdownMenuItem(value: 'F', child: Text('Feminino')),
                  DropdownMenuItem(value: 'M', child: Text('Masculino')),
                  DropdownMenuItem(value: 'O', child: Text('Outro')),
                ],
                onChanged:
                    _ocupado ? null : (v) => setState(() => _sexo = v ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tel,
                enabled: !_ocupado,
                keyboardType: TextInputType.phone,
                decoration: _dec('Telefone', dica: '(83) 99999-0000'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                enabled: !_ocupado,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('E-mail'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)
                      ? null
                      : 'E-mail inválido.';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _objetivo,
                enabled: !_ocupado,
                decoration: _dec('Objetivo'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _obs,
                enabled: !_ocupado,
                minLines: 3,
                maxLines: 6,
                decoration: _dec('Observações'),
              ),
              const SizedBox(height: 16),
              if (p?.temConsentimento ?? false)
                Row(
                  children: [
                    Icon(Icons.verified_user, color: tema.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Consentimento LGPD registrado em '
                        '${dataDeTimestamp(p!.consentimentoEm)}.',
                      ),
                    ),
                  ],
                )
              else
                CheckboxListTile(
                  value: _consentimento,
                  onChanged: _ocupado
                      ? null
                      : (v) => setState(() => _consentimento = v ?? false),
                  title: const Text(
                    'O paciente consentiu com o tratamento dos seus dados de saúde (LGPD)',
                  ),
                  subtitle:
                      const Text('Fica registrado com a data e a versão do texto.'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              if (_erro != null) ...[
                const SizedBox(height: 16),
                Text(_erro!, style: TextStyle(color: tema.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _ocupado ? null : _salvar,
                    icon: _ocupado
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Salvar'),
                  ),
                  if (_existente)
                    OutlinedButton(
                      onPressed: _ocupado ? null : _alternarArquivo,
                      child: Text(p!.ativo ? 'Arquivar' : 'Reativar'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
