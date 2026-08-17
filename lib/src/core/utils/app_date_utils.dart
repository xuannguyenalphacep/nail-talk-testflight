import 'package:intl/intl.dart';

import '../localization/app_localizer.dart';

class AppDateUtils {
  const AppDateUtils._();

  static String get _localeCode => AppLocalizer.current.language.code;

  static DateFormat get _timeFormat => DateFormat('HH:mm', _localeCode);
  static DateFormat get _dateTimeFormat => DateFormat(
    _localeCode == 'vi' ? 'dd/MM/yyyy HH:mm' : 'yyyy/MM/dd HH:mm',
    _localeCode,
  );
  static DateFormat get _dateFormat => DateFormat(
    _localeCode == 'vi' ? 'dd/MM/yyyy' : 'yyyy/MM/dd',
    _localeCode,
  );

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

    return DateFormat(
      _localeCode == 'vi' ? 'dd/MM' : 'M/d',
      _localeCode,
    ).format(dateTime);
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
