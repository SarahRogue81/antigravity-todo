import 'package:material_ui/material_ui.dart';

import '../constants/app_constants.dart';

/// Material 3 window size classes for phones, tablets, and Chromebooks/laptops.
enum WindowSizeClass {
  /// `< 600dp` (Phones in portrait)
  compact,

  /// `600dp – 839dp` (Tablets in portrait, large foldables, split-screen)
  medium,

  /// `>= 840dp` (Chromebooks / Googlebooks, laptops, tablets in landscape)
  expanded;

  static WindowSizeClass fromWidth(double width) {
    if (width < AppConstants.compactMaxWidth) {
      return WindowSizeClass.compact;
    } else if (width < AppConstants.mediumMaxWidth) {
      return WindowSizeClass.medium;
    } else {
      return WindowSizeClass.expanded;
    }
  }

  static WindowSizeClass of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  bool get isCompact => this == WindowSizeClass.compact;
  bool get isMedium => this == WindowSizeClass.medium;
  bool get isExpanded => this == WindowSizeClass.expanded;
}
