import 'package:flutter_test/flutter_test.dart';

import 'package:collecte_revendeurs/features/boutiques/application/collector_dashboard_metrics.dart';
import 'package:collecte_revendeurs/features/boutiques/domain/boutique.dart';

void main() {
  group('CollectorDashboardMetrics', () {
    test('aggregates totals, dates and zones', () {
      final now = DateTime(2024, 7, 10, 12);
      final dayBefore = now.subtract(const Duration(days: 1));
      final boutiques = [
        Boutique(
          id: '1',
          nom: 'Alpha',
          nomGerantComplet: 'Gerant A',
          collectorId: 'user',
          specialite: BoutiqueSpecialite.telephone,
          telephones: const ['0101'],
          latitude: 5.31,
          longitude: -4.02,
          submittedAt: now,
        ),
        Boutique(
          id: '2',
          nom: 'Beta',
          nomGerantComplet: 'Gerant B',
          collectorId: 'user',
          specialite: BoutiqueSpecialite.reparation,
          telephones: const ['0202'],
          latitude: 5.34,
          longitude: -4.01,
          submittedAt: now,
        ),
        Boutique(
          id: '3',
          nom: 'Gamma',
          nomGerantComplet: 'Gerant C',
          collectorId: 'user',
          specialite: BoutiqueSpecialite.telephone,
          telephones: const ['0303'],
          latitude: 5.39,
          longitude: -4.18,
          submittedAt: dayBefore,
        ),
      ];

      final metrics = CollectorDashboardMetrics.from(boutiques);

      expect(metrics.totalBoutiques, 3);
      expect(metrics.hasDateCoverage, isTrue);
      expect(metrics.hasGeoCoverage, isTrue);

      expect(metrics.dailyStats, hasLength(2));
      expect(metrics.dailyStats.first.count, 2);
      expect(metrics.dailyStats.first.date, DateTime(2024, 7, 10));

      expect(metrics.zoneStats, hasLength(2));
      expect(metrics.zoneStats.first.count, 2);
      expect(metrics.zoneStats.first.label, startsWith('Secteur'));
    });

    test('flags partial geo data when coordinates missing', () {
      final shops = [
        Boutique(
          id: 'missing',
          nom: 'Local',
          nomGerantComplet: 'Gerant',
          collectorId: 'user',
          specialite: BoutiqueSpecialite.telephone,
          telephones: const ['010101'],
          submittedAt: DateTime(2024, 1, 1),
        ),
      ];

      final metrics = CollectorDashboardMetrics.from(shops);

      expect(metrics.totalBoutiques, 1);
      expect(metrics.hasGeoCoverage, isFalse);
      expect(metrics.zoneStats.single.label, 'Localisation manquante');
    });
  });
}
