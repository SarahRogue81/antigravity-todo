import 'package:material_ui/material_ui.dart';

/// Dark-mode-only theme configuration for the Fractal Todo application.
abstract final class AppTheme {
  // Deep obsidian palette with luminous electric indigo & cyan accents.
  static const Color _obsidianBg = Color(0xFF0A0D14);
  static const Color _surfaceLow = Color(0xFF111622);
  static const Color _surfaceContainer = Color(0xFF161C2B);
  static const Color _surfaceHigh = Color(0xFF1E263A);
  static const Color _surfaceHighest = Color(0xFF263049);
  static const Color _primaryIndigo = Color(0xFF818CF8);
  static const Color _secondaryCyan = Color(0xFF38BDF8);
  static const Color _tertiaryMint = Color(0xFF34D399);
  static const Color _errorRose = Color(0xFFFB7185);
  static const Color _outlineSubtle = Color(0xFF2B354F);

  /// Accent colors mapped by nesting depth so sub-tasks and sub-sub-tasks
  /// visually distinguish their hierarchy level.
  static const List<Color> depthAccentColors = [
    Color(0xFF818CF8), // Depth 0: Electric Indigo
    Color(0xFF38BDF8), // Depth 1: Sky Cyan
    Color(0xFF34D399), // Depth 2: Emerald Mint
    Color(0xFFC084FC), // Depth 3: Vivid Purple
    Color(0xFFF472B6), // Depth 4: Neon Pink
    Color(0xFFFBBF24), // Depth 5+: Warm Amber
  ];

  /// Returns an accent color corresponding to the nesting [depth].
  static Color accentForDepth(int depth) {
    final safeIndex = depth < 0 ? 0 : depth % depthAccentColors.length;
    return depthAccentColors[safeIndex];
  }

  static ThemeData get darkTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _primaryIndigo,
      brightness: Brightness.dark,
    );

    final colorScheme = baseScheme.copyWith(
      brightness: Brightness.dark,
      primary: _primaryIndigo,
      onPrimary: const Color(0xFF090D16),
      primaryContainer: const Color(0xFF282E5C),
      onPrimaryContainer: const Color(0xFFE0E7FF),
      secondary: _secondaryCyan,
      onSecondary: const Color(0xFF061624),
      secondaryContainer: const Color(0xFF14354F),
      onSecondaryContainer: const Color(0xFFE0F2FE),
      tertiary: _tertiaryMint,
      onTertiary: const Color(0xFF051B14),
      tertiaryContainer: const Color(0xFF113D2F),
      onTertiaryContainer: const Color(0xFFD1FAE5),
      error: _errorRose,
      onError: const Color(0xFF2B060D),
      surface: _obsidianBg,
      onSurface: const Color(0xFFF1F5F9),
      onSurfaceVariant: const Color(0xFF94A3B8),
      surfaceContainerLowest: const Color(0xFF07090E),
      surfaceContainerLow: _surfaceLow,
      surfaceContainer: _surfaceContainer,
      surfaceContainerHigh: _surfaceHigh,
      surfaceContainerHighest: _surfaceHighest,
      outline: _outlineSubtle,
      outlineVariant: const Color(0xFF1F273B),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _obsidianBg,
      canvasColor: _obsidianBg,
      dividerColor: _outlineSubtle.withValues(alpha: 0.6),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: _obsidianBg,
        foregroundColor: Color(0xFFF1F5F9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: _surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _outlineSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _outlineSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _outlineSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryIndigo, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceLow,
        indicatorColor: _primaryIndigo.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFFF1F5F9)
                : const Color(0xFF94A3B8),
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _surfaceLow,
        indicatorColor: _primaryIndigo.withValues(alpha: 0.2),
        selectedIconTheme: const IconThemeData(color: _primaryIndigo),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
        selectedLabelTextStyle: const TextStyle(
          color: Color(0xFFF1F5F9),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _outlineSubtle),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceHighest,
        contentTextStyle: const TextStyle(color: Color(0xFFF1F5F9)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: Color(0xFF64748B), width: 1.6),
      ),
    );
  }
}
