import 'package:intl/intl.dart';

class AppDateUtils {
  const AppDateUtils._();

  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm');
  static final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');

  static DateTime? tryParse(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input;
    final raw = input.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static String formatRoomTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    if (now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day) {
      return _timeFormat.format(dateTime);
    }

    return DateFormat('M/d').format(dateTime);
  }

  static String formatFull(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _dateTimeFormat.format(dateTime);
  }

  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _dateFormat.format(dateTime);
  }
}
