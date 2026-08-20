import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../models/survey_result_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/survey_service.dart';

class SurveyResultsScreen extends StatefulWidget {
  const SurveyResultsScreen({super.key, required this.surveyId});

  final int surveyId;

  @override
  State<SurveyResultsScreen> createState() => _SurveyResultsScreenState();
}

class _SurveyResultsScreenState extends State<SurveyResultsScreen> {
  Future<SurveyResultModel>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??=
        SurveyService(context.read<AuthProvider>().api).results(widget.surveyId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Résultats')),
      body: FutureBuilder<SurveyResultModel>(
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
          final r = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(r.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(r.isAnonymous ? 'Mode : anonyme' : 'Mode : nominatif'),
              Text('Participants : ${r.participants} / ${r.targetCount}'),
              Text('Taux : ${r.participationRate}%'),
              const Divider(height: 32),
              for (final q in r.questions) ...[
                Text(
                  q['content']?.toString() ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('Type : ${q['type']} · réponses : ${q['total_answers']}'),
                if (q['average'] != null) Text('Moyenne : ${q['average']}'),
                if (q['distribution'] is Map)
                  ...((q['distribution'] as Map).entries.map(
                        (e) => Text('  ${e.key} : ${e.value}'),
                      )),
                if (q['responses'] is List)
                  ...((q['responses'] as List).take(8).map((resp) {
                    final name = resp['respondent']?.toString() ??
                        (r.isAnonymous ? 'Anonyme' : 'Employé');
                    return Text('  $name → ${resp['answer_value']}');
                  })),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }
}
