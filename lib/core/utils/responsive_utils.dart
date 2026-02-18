import 'package:flutter/material.dart';

class AppBreakpoints {
  static const double mobile = 0;
  static const double tablet = 600;
  static const double laptop = 1024;
}

enum AppLayoutType { mobile, tablet, laptop }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  AppLayoutType get layoutType {
    final w = screenWidth;
    if (w >= AppBreakpoints.laptop) return AppLayoutType.laptop;
    if (w >= AppBreakpoints.tablet) return AppLayoutType.tablet;
    return AppLayoutType.mobile;
  }

  bool get isMobile => layoutType == AppLayoutType.mobile;
  bool get isTablet => layoutType == AppLayoutType.tablet;
  bool get isLaptop => layoutType == AppLayoutType.laptop;
}

/// Use for content that should not stretch too wide on large screens (forms, cards).
///
/// Laptop returns a narrower value (480) than tablet (560) on purpose: on wide screens,
/// forms and centered content read better when kept moderately narrow; tablet gets
/// slightly more width for mid-size screens. Use this for forms and card content, not
/// for full-bleed layouts.
double contentMaxWidth(BuildContext context) {
  switch (context.layoutType) {
    case AppLayoutType.mobile:
      return double.infinity;
    case AppLayoutType.tablet:
      return 560;
    case AppLayoutType.laptop:
      return 480;
  }
}

/// Standard horizontal/outer padding by layout. Use consistently so screens don't mix
/// hardcoded values. Required for the feature plan below.
double responsivePadding(BuildContext context) {
  if (context.isLaptop) return 32;
  if (context.isTablet) return 24;
  return 16;
}

/// Use for in-call control sizes (e.g. mic circle, speaker button) in the Agora meeting
/// room. Single source of truth so radii are consistent and maintainable.
///
/// Values scale *down* on larger screens on purpose: on mobile, touch targets need to
/// be large (60) for fingers; on laptop, pointer/mouse allows smaller controls (48);
/// tablet (56) is in between. If you preferred "scale up on bigger screens," invert
/// the values and add a comment here.
double controlRadius(BuildContext context) {
  if (context.isLaptop) return 48;
  if (context.isTablet) return 56;
  return 60; // mobile default
}
