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

    // 1. Try ISO/default parsing
    try {
      return DateTime.parse(input);
    } catch (_) {}

    // 2. Remove ordinal suffix (8th → 8)
    String cleaned = input.replaceAllMapped(RegExp(r'(\d+)(st|nd|rd|th)'), (m) => m.group(1)!);

    // Normalize casing (march → March)
    cleaned = toBeginningOfSentenceCase(cleaned) ?? cleaned;

    // 3. Try known formats
    final formats = [
      // Text formats
      'd MMMM yyyy',
      'd MMM yyyy',
      'MMMM d yyyy',
      'MMM d yyyy',

      // Slash formats (IMPORTANT ⚠️ order matters)
      'dd/MM/yyyy',
      'd/M/yyyy',
      'MM/dd/yyyy',
      'M/d/yyyy',

      'dd/MM/yy',
      'd/M/yy',
      'MM/dd/yy',
      'M/d/yy',

      // Year-first
      'yyyy/MM/dd',
      'yyyy/M/d',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parseStrict(cleaned);
      } catch (_) {}
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

extension NullableStringExtension on String? {
  String get orEmpty => this ?? '';
  bool get isEmptyOrNull => this == null || this!.trim().isEmpty;
}
