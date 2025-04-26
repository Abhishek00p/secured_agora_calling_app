extension AppStringExtension on String {
  String get capitalizeAll => toUpperCase();
  String get lowerAll => toLowerCase();
  String get initalLetter => trim().isEmpty ? '' : trim()[0].capitalizeAll;
  String get initalTwoLetter =>
      trim().isEmpty
          ? ''
          : trim().split(' ').map((e) => e.initalLetter).join('');
  String get sentenceCase =>
      trim().isEmpty ? '' : substring(0, 1).capitalizeAll + substring(1);
  String get titleCase =>
      trim().isEmpty
          ? ''
          : split(' ')
              .map((e) => e.trim().isEmpty ? '' : e.trim()[0].capitalizeAll)
              .join(' ');
}
