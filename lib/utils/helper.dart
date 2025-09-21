class AppHelper {
  static String timeDifference(DateTime startTime, DateTime endTime) {
    final duration = endTime.difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    final hoursStr = hours.toString().padLeft(2, '0');
    final minutesStr = minutes.toString().padLeft(2, '0');

    if (hours > 0 && minutes > 0) {
      return '$hoursStr h $minutesStr mins';
    } else if (hours > 0) {
      return '$hoursStr hours';
    } else {
      return '$minutesStr mins';
    }
  }
}
