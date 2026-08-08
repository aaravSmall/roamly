import 'package:intl/intl.dart';

String formatVisitRange(DateTime start, DateTime end) {
  final sameDay =
      start.year == end.year && start.month == end.month && start.day == end.day;
  if (sameDay) return DateFormat.yMMMMd().format(start);

  final sameYear = start.year == end.year;
  if (sameYear) {
    return '${DateFormat.MMMd().format(start)} – ${DateFormat.MMMd().format(end)}, ${start.year}';
  }
  return '${DateFormat.yMMMd().format(start)} – ${DateFormat.yMMMd().format(end)}';
}
