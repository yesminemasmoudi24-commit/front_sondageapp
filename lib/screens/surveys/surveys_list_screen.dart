import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/survey_provider.dart';
import '../../theme/kpit_theme.dart';
import 'answer_survey_screen.dart';
import 'survey_detail_screen.dart';
import 'survey_form_screen.dart';

class SurveysListScreen extends StatelessWidget {
  const SurveysListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final surveys = context.watch<SurveyProvider>();
    final canManage = user.canManageSurveys;
    final items = surveys.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(canManage ? 'Sondages' : 'Mes sondages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: surveys.refresh,
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SurveyFormScreen()),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: surveys.loading && items.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: KpitTheme.lime),
            )
          : surveys.error != null && items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(surveys.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: surveys.refresh,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: KpitTheme.lime,
                  onRefresh: surveys.refresh,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 160),
                            Center(child: Text('Aucun sondage')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final s = items[i];
                            return Card(
                              child: ListTile(
                                title: Text(s.title),
                                subtitle: Text(
                                  '${s.status} · ${s.isAnonymous ? 'anonyme' : 'nominatif'} · ${s.questionsCount ?? s.questions.length} questions',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  if (canManage) {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SurveyDetailScreen(surveyId: s.id),
                                      ),
                                    );
                                  } else {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AnswerSurveyScreen(surveyId: s.id),
                                      ),
                                    );
                                  }
                                  if (context.mounted) {
                                    context.read<SurveyProvider>().refresh();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
