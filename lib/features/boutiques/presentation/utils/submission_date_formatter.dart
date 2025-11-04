String buildSubmissionLabel(DateTime? submittedAt) {
  if (submittedAt == null) {
    return 'Date non disponible';
  }
  final local = submittedAt.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');

  final day = twoDigits(local.day);
  final month = twoDigits(local.month);
  final year = local.year.toString().padLeft(4, '0');
  final hour = twoDigits(local.hour);
  final minute = twoDigits(local.minute);

  return 'Soumise le $day/$month/$year à $hour:$minute';
}
