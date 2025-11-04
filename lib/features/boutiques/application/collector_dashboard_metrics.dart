import '../domain/boutique.dart';

class CollectorDashboardMetrics {
  const CollectorDashboardMetrics({
    required this.totalBoutiques,
    required this.dailyStats,
    required this.zoneStats,
    required this.hasDateCoverage,
    required this.hasGeoCoverage,
  });

  factory CollectorDashboardMetrics.from(List<Boutique> boutiques) {
    if (boutiques.isEmpty) {
      return const CollectorDashboardMetrics(
        totalBoutiques: 0,
        dailyStats: [],
        zoneStats: [],
        hasDateCoverage: false,
        hasGeoCoverage: false,
      );
    }

    final daily = <DateTime, int>{};
    final geo = <String, _ZoneBucket>{};

    for (final boutique in boutiques) {
      final dateKey = _resolveDateKey(boutique);
      if (dateKey != null) {
        daily.update(dateKey, (value) => value + 1, ifAbsent: () => 1);
      }

      final zoneKey = _resolveZoneKey(boutique);
      final bucket = geo.putIfAbsent(zoneKey.label, () => _ZoneBucket(zoneKey));
      bucket.count++;
    }

    final sortedDaily = daily.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final dailyStats = sortedDaily
        .map(
          (entry) => DailySubmissionStat(
            date: entry.key,
            count: entry.value,
          ),
        )
        .toList(growable: false);

    final sortedZones = geo.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final zoneStats = sortedZones
        .map(
          (bucket) => ZoneSubmissionStat(
            label: bucket.zone.label,
            count: bucket.count,
            hasLocation: bucket.zone.hasLocation,
          ),
        )
        .toList(growable: false);

    final hasDateCoverage = dailyStats.isNotEmpty;
    final hasGeoCoverage =
        zoneStats.any((stat) => stat.hasLocation && stat.count > 0);

    return CollectorDashboardMetrics(
      totalBoutiques: boutiques.length,
      dailyStats: dailyStats,
      zoneStats: zoneStats,
      hasDateCoverage: hasDateCoverage,
      hasGeoCoverage: hasGeoCoverage,
    );
  }

  final int totalBoutiques;
  final List<DailySubmissionStat> dailyStats;
  final List<ZoneSubmissionStat> zoneStats;
  final bool hasDateCoverage;
  final bool hasGeoCoverage;
}

class DailySubmissionStat {
  const DailySubmissionStat({
    required this.date,
    required this.count,
  });

  final DateTime date;
  final int count;
}

class ZoneSubmissionStat {
  const ZoneSubmissionStat({
    required this.label,
    required this.count,
    required this.hasLocation,
  });

  final String label;
  final int count;
  final bool hasLocation;
}

class _ZoneKey {
  const _ZoneKey({required this.label, required this.hasLocation});

  final String label;
  final bool hasLocation;
}

class _ZoneBucket {
  _ZoneBucket(this.zone);

  final _ZoneKey zone;
  int count = 0;
}

DateTime? _resolveDateKey(Boutique boutique) {
  final date = boutique.submittedAt ?? boutique.dateDeVisite;
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day);
}

_ZoneKey _resolveZoneKey(Boutique boutique) {
  final latitude = boutique.latitude;
  final longitude = boutique.longitude;
  if (latitude == null || longitude == null) {
    return const _ZoneKey(
      label: 'Localisation manquante',
      hasLocation: false,
    );
  }

  final roundedLat = _roundToTenths(latitude);
  final roundedLng = _roundToTenths(longitude);
  final latitudeLabel =
      '${roundedLat.abs().toStringAsFixed(1)}${roundedLat >= 0 ? 'N' : 'S'}';
  final longitudeLabel =
      '${roundedLng.abs().toStringAsFixed(1)}${roundedLng >= 0 ? 'E' : 'O'}';

  return _ZoneKey(
    label: 'Secteur $latitudeLabel / $longitudeLabel',
    hasLocation: true,
  );
}

double _roundToTenths(double value) {
  return (value * 10).roundToDouble() / 10;
}
