import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../models/survey_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/survey_service.dart';

class AnswerSurveyScreen extends StatefulWidget {
  const AnswerSurveyScreen({super.key, required this.surveyId});

  final int surveyId;

  @override
  State<AnswerSurveyScreen> createState() => _AnswerSurveyScreenState();
}

class _AnswerSurveyScreenState extends State<AnswerSurveyScreen> {
  Future<SurveyModel>? _future;
  final Map<int, dynamic> _answers = {};
  bool _submitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??=
        SurveyService(context.read<AuthProvider>().api).show(widget.surveyId);
  }

  Future<void> _submit(SurveyModel survey) async {
    final payload = <Map<String, dynamic>>[];
    for (final q in survey.questions) {
      final value = _answers[q.id];
      if (value == null || (value is String && value.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Réponds à : ${q.content}')),
        );
        return;
      }
      payload.add({'question_id': q.id, 'answer_value': value});
    }

    setState(() => _submitting = true);
    try {
      await SurveyService(context.read<AuthProvider>().api)
          .submitAnswers(survey.id, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réponses envoyées')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildQuestion(SurveyModel survey, int index) {
    final q = survey.questions[index];
    switch (q.type) {
      case 'yes_no':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.content, style: Theme.of(context).textTheme.titleMedium),
            RadioListTile<String>(
              title: const Text('Oui'),
              value: 'yes',
              groupValue: _answers[q.id] as String?,
              onChanged: (v) => setState(() => _answers[q.id] = v),
            ),
            RadioListTile<String>(
              title: const Text('Non'),
              value: 'no',
              groupValue: _answers[q.id] as String?,
              onChanged: (v) => setState(() => _answers[q.id] = v),
            ),
          ],
        );
      case 'single_choice':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.content, style: Theme.of(context).textTheme.titleMedium),
            ...q.options.map(
              (o) => RadioListTile<String>(
                title: Text(o.optionText),
                value: o.optionText,
                groupValue: _answers[q.id] as String?,
                onChanged: (v) => setState(() => _answers[q.id] = v),
              ),
            ),
          ],
        );
      case 'multiple_choice':
        final selected = (_answers[q.id] as List<String>?) ?? <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.content, style: Theme.of(context).textTheme.titleMedium),
            ...q.options.map(
              (o) => CheckboxListTile(
                title: Text(o.optionText),
                value: selected.contains(o.optionText),
                onChanged: (checked) {
                  final next = List<String>.from(selected);
                  if (checked == true) {
                    next.add(o.optionText);
                  } else {
                    next.remove(o.optionText);
                  }
                  setState(() => _answers[q.id] = next);
                },
              ),
            ),
          ],
        );
      case 'satisfaction_scale':
        final value = (_answers[q.id] as int?) ?? 3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.content, style: Theme.of(context).textTheme.titleMedium),
            Text('Note : $value / 5'),
            Slider(
              value: value.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$value',
              onChanged: (v) => setState(() => _answers[q.id] = v.round()),
            ),
          ],
        );
      case 'open_answer':
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.content, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _answers[q.id] as String? ?? '',
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ta réponse',
              ),
              onChanged: (v) => _answers[q.id] = v,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Répondre')),
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
          final survey = snap.data!;
          if (survey.questions.isEmpty) {
            return const Center(child: Text('Aucune question'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(survey.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: survey.isAnonymous
                      ? const Color(0x22B8FF00)
                      : const Color(0x225CC8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  survey.isAnonymous
                      ? 'Réponses anonymes — ton nom ne sera pas affiché dans les résultats.'
                      : 'Réponses nominatives — ton nom sera associé à tes réponses.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < survey.questions.length; i++) ...[
                _buildQuestion(survey, i),
                const Divider(height: 32),
              ],
              FilledButton(
                onPressed: _submitting ? null : () => _submit(survey),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Envoyer mes réponses'),
              ),
            ],
          );
        },
      ),
    );
  }
}
