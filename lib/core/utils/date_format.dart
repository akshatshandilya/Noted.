import 'package:intl/intl.dart';

String formatNoteDate(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return DateFormat('h:mm a').format(d);
  }
  if (d.year == now.year) return DateFormat('MMM d').format(d);
  return DateFormat('MMM d, y').format(d);
}
