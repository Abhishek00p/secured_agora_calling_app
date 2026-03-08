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
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool get isTomorrow {
    final date = this;
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day + 1;
  }

  bool get isYesterday {
    final date = this;
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day - 1;
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

    String getDaySuffix(int day) {
      if (day >= 11 && day <= 13) return 'th';
      switch (day % 10) {
        case 1:
          return 'st';
        case 2:
          return 'nd';
        case 3:
          return 'rd';
        default:
          return 'th';
      }
    }

    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    final suffix = getDaySuffix(date.day);
    final monthName = months[date.month];

    return '${date.day}$suffix $monthName ${date.year}';
  }

  String get formatTime {
    final date = this;
    if (date == null) return 'NA';
    return DateFormat('hh:mm a').format(date);
  }

  String get formatTimeWithSeconds {
    final date = this;
    if (date == null) return 'NA';
    return DateFormat('hh:mm:ss a').format(date);
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
