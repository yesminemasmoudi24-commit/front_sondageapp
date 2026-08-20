import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_exception.dart';
import '../../models/question_model.dart';
import '../../models/survey_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/survey_provider.dart';
import '../../services/survey_service.dart';
import '../../theme/kpit_theme.dart';

class _DraftQuestion {
  _DraftQuestion({
    required this.content,
    required this.type,
    this.options = const [],
  });

  String content;
  String type;
  List<String> options;
}

class SurveyFormScreen extends StatefulWidget {
  const SurveyFormScreen({super.key, this.surveyId});

  final int? surveyId;

  @override
  State<SurveyFormScreen> createState() => _SurveyFormScreenState();
}

class _SurveyFormScreenState extends State<SurveyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  String _status = 'active';
  bool _targetAll = true;
  bool _isAnonymous = false;
  bool _loading = false;
  final List<_DraftQuestion> _questions = [];

  bool get _isCreate => widget.surveyId == null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          start ? (_start ?? now) : (_end ?? now.add(const Duration(days: 7))),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _addQuestionDialog() async {
    final content = TextEditingController();
    final optionsCtrl = TextEditingController(text: 'Option 1\nOption 2');
    var type = 'yes_no';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Ajouter une question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: content,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  items: [
                    for (final t in QuestionModel.types)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? type),
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (type == 'single_choice' || type == 'multiple_choice') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: optionsCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Options (1 par ligne)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final text = content.text.trim();
    if (text.isEmpty) return;

    final options = optionsCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if ((type == 'single_choice' || type == 'multiple_choice') &&
        options.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Au moins 2 options requises')),
      );
      return;
    }

    setState(() {
      _questions.add(
        _DraftQuestion(
          content: text,
          type: type,
          options: options,
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis les dates début / fin')),
      );
      return;
    }
    if (_isCreate && _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins une question')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final service = SurveyService(api);
      final body = <String, dynamic>{
        'title': _title.text.trim(),
        'start_date': _fmt(_start!),
        'end_date': _fmt(_end!),
        'status': _status,
        'target_all': _targetAll,
        'is_anonymous': _isAnonymous,
      };
      final desc = _description.text.trim();
      if (desc.isNotEmpty) {
        body['description'] = desc;
      }

      if (_isCreate) {
        var survey = await service.create(body);

        for (var i = 0; i < _questions.length; i++) {
          final q = _questions[i];
          final qBody = <String, dynamic>{
            'content': q.content,
            'type': q.type,
            'order': i,
          };
          if (q.type == 'single_choice' || q.type == 'multiple_choice') {
            qBody['options'] = q.options;
          }
          await service.addQuestion(survey.id, qBody);
        }

        try {
          survey = await service.show(survey.id);
        } catch (_) {
          // QR déjà présent dans la réponse create
        }

        if (!mounted) return;
        context.read<SurveyProvider>().upsert(survey);
        setState(() => _loading = false);

        // Dialogue QR hors du try réseau pour éviter un faux "blocage"
        if (!mounted) return;
        await showSurveyQrShareDialog(context, survey);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      final updated = await service.update(widget.surveyId!, body);
      if (!mounted) return;
      context.read<SurveyProvider>().upsert(updated);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur création sondage: $e')),
      );
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? 'Nouveau sondage' : 'Modifier sondage'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _start == null ? 'Date début' : 'Début : ${_fmt(_start!)}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(start: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title:
                  Text(_end == null ? 'Date fin' : 'Fin : ${_fmt(_end!)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(start: false),
            ),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Statut',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('draft')),
                DropdownMenuItem(value: 'active', child: Text('active')),
                DropdownMenuItem(value: 'closed', child: Text('closed')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cibler tous les employés'),
              subtitle: const Text(
                'Sinon seuls les employés ciblés verront le sondage',
              ),
              value: _targetAll,
              onChanged: (v) => setState(() => _targetAll = v),
            ),
            const SizedBox(height: 8),
            Text(
              'Type de réponses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Avec nom'),
                  icon: Icon(Icons.badge_outlined),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Anonyme'),
                  icon: Icon(Icons.visibility_off_outlined),
                ),
              ],
              selected: {_isAnonymous},
              onSelectionChanged: (set) {
                setState(() => _isAnonymous = set.first);
              },
            ),
            const SizedBox(height: 6),
            Text(
              _isAnonymous
                  ? 'Les résultats ne montreront pas le nom des employés.'
                  : 'Les réponses seront associées au nom de l’employé.',
              style: const TextStyle(color: KpitTheme.muted, fontSize: 12),
            ),
            if (_isCreate) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Questions (${_questions.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _addQuestionDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_questions.isEmpty)
                const Text(
                  'Ajoute les questions du sondage avant de publier.',
                  style: TextStyle(color: KpitTheme.muted),
                )
              else
                ..._questions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final q = entry.value;
                  return Card(
                    child: ListTile(
                      title: Text(q.content),
                      subtitle: Text(q.type),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _questions.removeAt(i)),
                      ),
                    ),
                  );
                }),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isCreate
                        ? 'Créer et partager le QR'
                        : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showSurveyQrShareDialog(
  BuildContext context,
  SurveyModel survey,
) async {
  final link = survey.qrCode?.link;
  if (link == null || link.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sondage créé, mais QR indisponible pour le moment'),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KpitTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KpitTheme.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sondage créé — partager le QR',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              survey.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KpitTheme.muted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: link,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              link,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: KpitTheme.muted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Lien copié')),
                        );
                      }
                    },
                    child: const Text('Copier'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'Sondage KPIT « ${survey.title} »\n$link',
                          subject: 'Sondage KPIT',
                        ),
                      );
                    },
                    child: const Text('Partager'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
