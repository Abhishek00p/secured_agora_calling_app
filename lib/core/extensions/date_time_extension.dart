import 'package:intl/intl.dart';

extension AppDateTimeExtension on DateTime? {
  String get formatDateTime {
    final date = this;
    if (date == null) return 'N/A';
    final formattedTime = DateFormat('h:mm a').format(date);
    return '${date.day}/${date.month}/${date.year} $formattedTime';
  }
}
