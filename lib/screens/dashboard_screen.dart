import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../models/dashboard_model.dart';
import '../providers/auth_provider.dart';
import '../services/dashboard_service.dart';
import '../theme/kpit_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<DashboardModel>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<DashboardModel> _load() {
    return DashboardService(context.read<AuthProvider>().api).fetch();
  }

  num _n(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is num) return v;
    return num.tryParse('$v') ?? 0;
  }

  String _statusLabel(String? raw) {
    switch (raw) {
      case 'active':
        return 'Actif';
      case 'draft':
        return 'Brouillon';
      case 'closed':
        return 'Clôturé';
      case 'cancelled':
        return 'Annulé';
      default:
        return raw ?? '—';
    }
  }

  Color _statusColor(String? raw) {
    switch (raw) {
      case 'active':
        return KpitTheme.lime;
      case 'draft':
        return const Color(0xFFFFC107);
      case 'closed':
        return const Color(0xFF7A7A7A);
      case 'cancelled':
        return const Color(0xFFFF5C5C);
      default:
        return KpitTheme.muted;
    }
  }

  String _shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final now = DateTime.now();
    final dateLabel =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Scaffold(
      body: FutureBuilder<DashboardModel>(
        future: _future!,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: KpitTheme.lime),
            );
          }
          if (snap.hasError) {
            final msg = snap.error is ApiException
                ? (snap.error as ApiException).message
                : snap.error.toString();
            return _ErrorState(
              message: msg,
              onRetry: () => setState(() => _future = _load()),
            );
          }

          final d = snap.data!;
          final surveysTotal = _n(d.surveys, 'total');
          final surveysActive = _n(d.surveys, 'active');
          final surveysDraft = _n(d.surveys, 'draft');
          final surveysClosed = _n(d.surveys, 'closed');
          final employeesActive = _n(d.employees, 'active');
          final employeesTotal = _n(d.employees, 'total');
          final participationRate = _n(d.participation, 'estimated_rate');
          final uniqueParticipants =
              _n(d.participation, 'unique_participants');
          final totalAnswers = _n(d.participation, 'total_answers');
          final delegationsActive = _n(d.delegations, 'active');
          final delegationsTotal = _n(d.delegations, 'total');

          return RefreshIndicator(
            color: KpitTheme.lime,
            backgroundColor: KpitTheme.surface,
            onRefresh: () async => setState(() => _future = _load()),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _DashboardHeader(
                    userName: user.name,
                    role: user.isAdmin ? 'Administrateur' : 'Délégué',
                    dateLabel: dateLabel,
                    onRefresh: () => setState(() => _future = _load()),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 640;
                        final cards = [
                          _KpiCard(
                            label: 'Sondages actifs',
                            value: '$surveysActive',
                            hint: '$surveysTotal au total',
                            icon: Icons.poll_rounded,
                            accent: KpitTheme.lime,
                          ),
                          _KpiCard(
                            label: 'Collaborateurs',
                            value: '$employeesActive',
                            hint: '$employeesTotal enregistrés',
                            icon: Icons.groups_rounded,
                            accent: const Color(0xFF5CC8FF),
                          ),
                          _KpiCard(
                            label: 'Participation',
                            value: '${participationRate.toStringAsFixed(
                              participationRate % 1 == 0 ? 0 : 1,
                            )}%',
                            hint: '$uniqueParticipants participants',
                            icon: Icons.trending_up_rounded,
                            accent: const Color(0xFFFFC857),
                          ),
                          _KpiCard(
                            label: 'Délégations',
                            value: '$delegationsActive',
                            hint: '$delegationsTotal au total',
                            icon: Icons.handshake_rounded,
                            accent: const Color(0xFFC9A0FF),
                          ),
                        ];

                        if (wide) {
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < cards.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(child: cards[i]),
                                ],
                              ],
                            ),
                          );
                        }

                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.05,
                          children: cards,
                        );
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _SectionPanel(
                      title: 'Vue d’ensemble',
                      subtitle: 'Répartition opérationnelle',
                      child: Column(
                        children: [
                          _OverviewRow(
                            label: 'Sondages',
                            items: [
                              _MiniStat('Actifs', surveysActive, KpitTheme.lime),
                              _MiniStat('Brouillons', surveysDraft,
                                  const Color(0xFFFFC107)),
                              _MiniStat('Clôturés', surveysClosed,
                                  KpitTheme.muted),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _ParticipationBar(
                            rate: participationRate.toDouble(),
                            participants: uniqueParticipants,
                            answers: totalAnswers,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _SectionPanel(
                      title: 'Sondages récents',
                      subtitle: 'Dernières campagnes créées',
                      child: d.recentSurveys.isEmpty
                          ? const _EmptyLine('Aucun sondage récent')
                          : Column(
                              children: [
                                for (var i = 0;
                                    i < d.recentSurveys.length;
                                    i++) ...[
                                  if (i > 0)
                                    const Divider(
                                      height: 1,
                                      color: KpitTheme.border,
                                    ),
                                  _RecentSurveyTile(
                                    title: d.recentSurveys[i]['title']
                                            ?.toString() ??
                                        'Sans titre',
                                    status: _statusLabel(
                                      d.recentSurveys[i]['status']?.toString(),
                                    ),
                                    statusColor: _statusColor(
                                      d.recentSurveys[i]['status']?.toString(),
                                    ),
                                    period:
                                        '${_shortDate(d.recentSurveys[i]['start_date']?.toString())} → ${_shortDate(d.recentSurveys[i]['end_date']?.toString())}',
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
                if (user.isAdmin)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _SectionPanel(
                        title: 'Délégations récentes',
                        subtitle: 'Pouvoirs temporairement délégués',
                        child: d.recentDelegations.isEmpty
                            ? const _EmptyLine('Aucune délégation récente')
                            : Column(
                                children: [
                                  for (var i = 0;
                                      i < d.recentDelegations.length;
                                      i++) ...[
                                    if (i > 0)
                                      const Divider(
                                        height: 1,
                                        color: KpitTheme.border,
                                      ),
                                    _RecentDelegationTile(
                                      name: d.recentDelegations[i]
                                                  ['delegated_user']
                                              ?.toString() ??
                                          '—',
                                      admin: d.recentDelegations[i]['admin']
                                              ?.toString() ??
                                          '—',
                                      status: _statusLabel(
                                        d.recentDelegations[i]['status']
                                            ?.toString(),
                                      ),
                                      statusColor: _statusColor(
                                        d.recentDelegations[i]['status']
                                            ?.toString(),
                                      ),
                                      period:
                                          '${_shortDate(d.recentDelegations[i]['start_date']?.toString())} → ${_shortDate(d.recentDelegations[i]['end_date']?.toString())}',
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.userName,
    required this.role,
    required this.dateLabel,
    required this.onRefresh,
  });

  final String userName;
  final String role;
  final String dateLabel;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0A0A),
            Color(0xFF12180A),
            Color(0xFF050505),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/kpit_logo.png',
                  height: 28,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                Text(
                  dateLabel,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: KpitTheme.muted,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Actualiser',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  color: KpitTheme.muted,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Tableau de bord',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: KpitTheme.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bonjour, $userName',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                color: KpitTheme.muted,
              ),
            ),
            const SizedBox(height: 14),
            _HeaderChip(
              icon: Icons.verified_user_outlined,
              label: role,
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasize
            ? KpitTheme.lime.withValues(alpha: 0.12)
            : KpitTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: emphasize
              ? KpitTheme.lime.withValues(alpha: 0.35)
              : KpitTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: emphasize ? KpitTheme.lime : KpitTheme.muted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: emphasize ? KpitTheme.lime : KpitTheme.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KpitTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpitTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: KpitTheme.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: KpitTheme.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              color: KpitTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: KpitTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpitTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: KpitTheme.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: KpitTheme.muted,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({required this.label, required this.items});

  final String label;
  final List<_MiniStat> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KpitTheme.muted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: items[i]),
            ],
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color);

  final String label;
  final num value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: KpitTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KpitTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: KpitTheme.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              color: KpitTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipationBar extends StatelessWidget {
  const _ParticipationBar({
    required this.rate,
    required this.participants,
    required this.answers,
  });

  final double rate;
  final num participants;
  final num answers;

  @override
  Widget build(BuildContext context) {
    final clamped = (rate / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Taux de participation estimé',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: KpitTheme.muted,
              ),
            ),
            const Spacer(),
            Text(
              '${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1)}%',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: KpitTheme.lime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 8,
            backgroundColor: KpitTheme.surfaceElevated,
            color: KpitTheme.lime,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$participants participants uniques · $answers réponses collectées',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            color: KpitTheme.muted,
          ),
        ),
      ],
    );
  }
}

class _RecentSurveyTile extends StatelessWidget {
  const _RecentSurveyTile({
    required this.title,
    required this.status,
    required this.statusColor,
    required this.period,
  });

  final String title;
  final String status;
  final Color statusColor;
  final String period;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: KpitTheme.lime.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 18,
              color: KpitTheme.lime,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: KpitTheme.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  period,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: KpitTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(label: status, color: statusColor),
        ],
      ),
    );
  }
}

class _RecentDelegationTile extends StatelessWidget {
  const _RecentDelegationTile({
    required this.name,
    required this.admin,
    required this.status,
    required this.statusColor,
    required this.period,
  });

  final String name;
  final String admin;
  final String status;
  final Color statusColor;
  final String period;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFC9A0FF).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 18,
              color: Color(0xFFC9A0FF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: KpitTheme.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Par $admin · $period',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: KpitTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(label: status, color: statusColor),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          color: KpitTheme.muted,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: KpitTheme.muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(color: KpitTheme.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
