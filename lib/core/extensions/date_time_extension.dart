import 'package:intl/intl.dart';

extension AppDateTimeExtension on DateTime? {
  String get formatDateTime {
    final date = this;
    if (date == null) return 'N/A';
    final formattedTime = DateFormat('h:mm a').format(date);
    return '${date.isToday ? 'Today' : '${date.day}/${date.month}/${date.year}'} $formattedTime';
  }

  bool get isToday {
    final date = this;
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isTomorrow {
    final date = this;
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day + 1;
  }

  bool get isYesterday {
    final date = this;
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;
  }

  String get meetStartTime {
    final date = this;
    if (date == null) return 'N/A';
    final now = DateTime.now();
    if (!date.isToday) {
      return 'Scheduled for ${date.formatDate}';
    }
    final difference = date.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);
    if (hours > 0) {
      return 'Starts in $hours Hours';
    } else if (minutes > 0) {
      return 'Starts in $minutes minutes';
    } else if (seconds > 0) {
      return 'Starts in $seconds seconds';
    } else if (seconds < 0) {
      return 'Scheduled for ${date.formatTime}';
    } else {
      return 'Started';
    }
  }

  String get formatDate {
    final date = this;
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  String get formatTime {
    final date = this;
    if (date == null) return 'N/A';
    final timeofDate = date.hour >= 12 ? 'PM' : 'AM';
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute < 10 ? '0${date.minute}' : date.minute;
    final formattedTime = '$hour:$minute $timeofDate';
    return formattedTime;
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
