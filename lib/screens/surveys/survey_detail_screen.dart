import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../models/question_model.dart';
import '../../models/survey_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/survey_provider.dart';
import '../../services/survey_service.dart';
import 'survey_form_screen.dart';
import 'survey_results_screen.dart';

class SurveyDetailScreen extends StatefulWidget {
  const SurveyDetailScreen({super.key, required this.surveyId});

  final int surveyId;

  @override
  State<SurveyDetailScreen> createState() => _SurveyDetailScreenState();
}

class _SurveyDetailScreenState extends State<SurveyDetailScreen> {
  Future<SurveyModel>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<SurveyModel> _load() =>
      SurveyService(context.read<AuthProvider>().api).show(widget.surveyId);

  Future<void> _addQuestion(SurveyModel survey) async {
    final content = TextEditingController();
    String type = 'yes_no';
    final optionsCtrl = TextEditingController(text: 'Oui\nNon');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter une question'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: content,
                decoration: const InputDecoration(
                  labelText: 'Contenu',
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
                onChanged: (v) => type = v ?? type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: optionsCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Options (1 par ligne, si choix)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final body = <String, dynamic>{
      'content': content.text.trim(),
      'type': type,
    };
    if (type == 'single_choice' || type == 'multiple_choice') {
      body['options'] = optionsCtrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    try {
      await SurveyService(context.read<AuthProvider>().api)
          .addQuestion(survey.id, body);
      if (mounted) setState(() => _future = _load());
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail sondage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Résultats',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SurveyResultsScreen(surveyId: widget.surveyId),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<SurveyModel>(
        future: _future!,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final msg = snap.error is ApiException
                ? (snap.error as ApiException).message
                : snap.error.toString();
            return Center(child: Text(msg));
          }
          final s = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(s.title, style: Theme.of(context).textTheme.headlineSmall),
              if (s.description != null && s.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(s.description!),
              ],
              const SizedBox(height: 8),
              Text('Statut : ${s.status}'),
              Text('Du ${s.startDate ?? '-'} au ${s.endDate ?? '-'}'),
              if (s.qrCode != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lien QR'),
                  subtitle: Text(s.qrCode!.link),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: s.qrCode!.link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lien copié')),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => SurveyFormScreen(surveyId: s.id),
                        ),
                      );
                      if (updated == true && mounted) {
                        setState(() => _future = _load());
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifier'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _addQuestion(s),
                    icon: const Icon(Icons.add),
                    label: const Text('Question'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        var current = s;
                        if (current.qrCode == null ||
                            current.qrCode!.link.isEmpty) {
                          await SurveyService(context.read<AuthProvider>().api)
                              .generateQr(s.id);
                          current = await SurveyService(
                            context.read<AuthProvider>().api,
                          ).show(s.id);
                          if (mounted) setState(() => _future = _load());
                        }
                        if (!mounted) return;
                        await showSurveyQrShareDialog(context, current);
                      } on ApiException catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    },
                    icon: const Icon(Icons.qr_code),
                    label: const Text('QR'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Supprimer ?'),
                          content: const Text('Cette action est irréversible.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Annuler'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true || !mounted) return;
                      try {
                        await SurveyService(context.read<AuthProvider>().api)
                            .delete(s.id);
                        if (mounted) {
                          context.read<SurveyProvider>().removeById(s.id);
                          Navigator.pop(context, true);
                        }
                      } on ApiException catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer'),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text('Questions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (s.questions.isEmpty)
                const Text('Aucune question')
              else
                ...s.questions.map(
                  (q) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(q.content),
                    subtitle: Text(q.type),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        try {
                          await SurveyService(context.read<AuthProvider>().api)
                              .deleteQuestion(q.id);
                          if (mounted) setState(() => _future = _load());
                        } on ApiException catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
