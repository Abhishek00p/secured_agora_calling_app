import 'package:flutter/widgets.dart';

extension AppIntExtension on int {
  String get formatDuration {
    final hours = this ~/ 3600;
    final minutes = (this % 3600) ~/ 60;
    final seconds = this % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$seconds';
    }
  }

  DateTime get toDateTime {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(this);
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
    );
  }
}

extension AppNumExtension on num {
  SizedBox get h {
    return SizedBox(height: toDouble());
  }

  SizedBox get w {
    return SizedBox(width: toDouble());
  }

  SizedBox get hw {
    return SizedBox(width: toDouble(), height: toDouble());
  }
}
