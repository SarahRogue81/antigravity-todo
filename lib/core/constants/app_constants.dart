/// Central constants for the Todo application.
abstract final class AppConstants {
  /// Hive box name for persisting todo items.
  static const String todoBoxName = 'todos_box';

  /// Responsive window size breakpoints (Material 3).
  static const double compactMaxWidth = 600;
  static const double mediumMaxWidth = 840;
  static const double expandedContentMaxWidth = 1280;
}
