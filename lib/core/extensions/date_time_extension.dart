import 'package:intl/intl.dart';

extension AppDateTimeExtension on DateTime? {
  String get formatDateTime {
    final date = this;
    if (date == null) return 'N/A';
    final formattedTime = DateFormat('h:mm a').format(date);
    return '${date.day}/${date.month}/${date.year} $formattedTime';
  }

   String get formatDate {
    final date = this;
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

       String get formatTime {
    final date = this;
    if (date == null) return 'N/A';
    return '${date.hour}:${date.minute}';
  }

  int get differenceInDays {
    final date = this;
    if (date == null) return 0;
    final now = DateTime.now();
    return now.difference(date).inDays;
  }
  int get differenceInMinutes {
    final date = this;
    if (date == null) return 0;
    final now = DateTime.now();
    return now.difference(date).inMinutes;
  }
}
