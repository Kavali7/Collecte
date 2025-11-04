import 'package:flutter/material.dart';

import '../../application/boutique_list_state.dart';
import '../../application/collector_dashboard_metrics.dart';

class BoutiqueDashboard extends StatelessWidget {
  const BoutiqueDashboard({
    super.key,
    required this.state,
    required this.onRefresh,
  });

  final BoutiqueListState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final metrics = state.dashboardMetrics;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _DashboardStatCard(metrics: metrics),
          const SizedBox(height: 16),
          if (state.isOfflineFallback) const _OfflineBanner(),
          if (state.isOfflineFallback) const SizedBox(height: 16),
          _DailyEvolutionSection(metrics: metrics),
          const SizedBox(height: 16),
          _ZoneBreakdownSection(metrics: metrics),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({required this.metrics});

  final CollectorDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total collecte',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              metrics.totalBoutiques.toString(),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Compteur actualise automatiquement pour votre identifiant.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyEvolutionSection extends StatelessWidget {
  const _DailyEvolutionSection({required this.metrics});

  final CollectorDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final entries = metrics.dailyStats.take(7).toList(growable: false);
    return _SectionShell(
      title: 'Evolution recentre',
      subtitle:
          'Vue journaliere sur les sept dernieres dates de soumission connues.',
      child: entries.isEmpty
          ? const _EmptyHint(
              message:
                  'Aucune soumission horodatee. Les dates seront remplies lors de la prochaine synchronisation.',
            )
          : Column(
              children: entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LabeledProgress(
                        label: _formatDay(entry.date),
                        value: entry.count,
                        totalReference: entries.first.count,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _ZoneBreakdownSection extends StatelessWidget {
  const _ZoneBreakdownSection({required this.metrics});

  final CollectorDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final entries = metrics.zoneStats.take(6).toList(growable: false);

    return _SectionShell(
      title: 'Repartition geographique',
      subtitle:
          'Regroupement par zones deduites des coordonnees collectees (arrondi au decimeme).',
      child: entries.isEmpty
          ? const _EmptyHint(
              message:
                  'Aucune coordonnee associee. Enregistre les positions GPS pour cartographier tes visites.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LabeledProgress(
                      label: entry.label,
                      value: entry.count,
                      totalReference: entries.first.count,
                    ),
                  ),
                ),
                if (!metrics.hasGeoCoverage)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Certaines boutiques n\'ont pas encore de coordonnees GPS.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _LabeledProgress extends StatelessWidget {
  const _LabeledProgress({
    required this.label,
    required this.value,
    required this.totalReference,
  });

  final String label;
  final int value;
  final int totalReference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseline = totalReference <= 0 ? 1 : totalReference;
    final progress = value / baseline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress.clamp(0, 1),
            backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.blueGrey,
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFEF6C00)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Donnees partielles',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF6C00),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Connexion indisponible. Les chiffres proviennent du cache local et seront verifies des que possible.',
                  style: TextStyle(color: Color(0xFF795548)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDay(DateTime date) {
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${pad(date.day)}/${pad(date.month)}';
}
