import 'package:intl/intl.dart';

extension AppStringExtension on String {
  String get capitalizeAll => toUpperCase();
  String get lowerAll => toLowerCase();
  String get initalLetter => trim().isEmpty ? '' : trim()[0].capitalizeAll;
  String get initalTwoLetter => trim().isEmpty ? '' : trim().split(' ').map((e) => e.initalLetter).join('');
  String get sentenceCase => trim().isEmpty ? '' : substring(0, 1).capitalizeAll + substring(1);
  String get titleCase =>
      trim().isEmpty
          ? ''
          : split(
            ' ',
          ).map((e) => e.trim().isEmpty ? '' : '${e.trim()[0].capitalizeAll}${e.trim().substring(1)}').join(' ');

  DateTime get toDateTimeFromEpoch {
    final date = this;
    if (date.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.parse(date);
  }

  DateTime get toDateTime {
    final input = trim();
    if (input.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);

    // List of supported formats
    final formats = [
      DateFormat("yyyy-MM-dd"), // 2025-11-13
      DateFormat("dd/MM/yyyy"), // 13/11/2025
      DateFormat("dd-MM-yyyy"), // 13-11-2025
      DateFormat("MM/dd/yyyy"), // 11/13/2025
      DateFormat("yyyy/MM/dd"), // 2025/11/13
      DateFormat("yyyy.MM.dd"), // 2025.11.13
      DateFormat("dd.MM.yyyy"), // 13.11.2025
    ];

    for (final format in formats) {
      try {
        return format.parseStrict(input);
      } catch (_) {
        // Try next format
      }
    }

    // Fallback to DateTime.parse for ISO and full formats
    try {
      return DateTime.parse(input);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0); // Fallback default
    }
  }
}
