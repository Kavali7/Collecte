class DayRange {
  DayRange(DateTime reference)
    : reference = normalize(reference),
      start = normalize(reference),
      end = normalize(reference).add(const Duration(days: 1));

  final DateTime reference;
  final DateTime start;
  final DateTime end;

  static DateTime normalize(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool contains(DateTime? input) {
    if (input == null) return false;
    final local = input.isUtc ? input.toLocal() : input;
    return !local.isBefore(start) && local.isBefore(end);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
