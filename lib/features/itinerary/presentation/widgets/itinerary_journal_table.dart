import 'package:flutter/material.dart';

import '../../domain/collector_track_point.dart';

const Duration kAnomalousStopDuration = Duration(minutes: 30);

@immutable
class ItineraryJournalEntry {
  const ItineraryJournalEntry({
    required this.point,
    required this.arrival,
    required this.duration,
    required this.usesRealtimeFallback,
  });

  final CollectorTrackPoint point;
  final DateTime arrival;
  final Duration duration;
  final bool usesRealtimeFallback;

  bool get isAnomalous => duration >= kAnomalousStopDuration;
}

List<ItineraryJournalEntry> buildItineraryJournalEntries(
  List<CollectorTrackPoint> points, {
  DateTime? currentTime,
}) {
  if (points.isEmpty) return const [];
  final now = currentTime ?? DateTime.now();
  final entries = <ItineraryJournalEntry>[];
  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    final fallback = i == points.length - 1;
    final nextTimestamp = fallback ? now : points[i + 1].timestamp;
    final rawDuration = nextTimestamp.difference(point.timestamp);
    entries.add(
      ItineraryJournalEntry(
        point: point,
        arrival: point.timestamp,
        duration: rawDuration.isNegative ? Duration.zero : rawDuration,
        usesRealtimeFallback: fallback,
      ),
    );
  }
  return entries;
}

String formatJournalDuration(Duration duration) {
  if (duration.isNegative) {
    duration = Duration.zero;
  }
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  if (hours > 0) {
    final minutesLabel = minutes.toString().padLeft(2, '0');
    return '${hours}h ${minutesLabel}min';
  }
  if (minutes > 0) {
    return '${minutes}min';
  }
  return '${seconds}s';
}

String formatJournalTime(DateTime dateTime) {
  return '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
}

String formatCoordinate(double value) => value.toStringAsFixed(5);

class ItineraryJournalTable extends StatelessWidget {
  const ItineraryJournalTable({
    super.key,
    required this.entries,
    required this.height,
  });

  final List<ItineraryJournalEntry> entries;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );
    final anomalyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.error,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: height,
      child: Card(
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _HeaderCell('N°', flex: 1, style: headerStyle),
                  _HeaderCell('Quartier', flex: 3, style: headerStyle),
                  _HeaderCell('Lat/Long', flex: 3, style: headerStyle),
                  _HeaderCell('Heure', flex: 2, style: headerStyle),
                  _HeaderCell('Duree', flex: 2, style: headerStyle),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: entries.isEmpty
                  ? const _EmptyJournalMessage()
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      primary: false,
                      physics: const ClampingScrollPhysics(),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 1),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final durationText = formatJournalDuration(
                          entry.duration,
                        );
                        final durationTextStyle = entry.isAnomalous
                            ? anomalyStyle
                            : theme.textTheme.bodyMedium;
                        final latLongLabel =
                            '${formatCoordinate(entry.point.latitude)}\n'
                            '${formatCoordinate(entry.point.longitude)}';
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  entry.point.quartier,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  latLongLabel,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  formatJournalTime(entry.arrival),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  durationText,
                                  textAlign: TextAlign.center,
                                  style: durationTextStyle,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {required this.flex, this.style});

  final String label;
  final int flex;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(label, textAlign: TextAlign.center, style: style),
    );
  }
}

class _EmptyJournalMessage extends StatelessWidget {
  const _EmptyJournalMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Aucun arret confirme pour cette date.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
