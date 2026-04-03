import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/workspace_config.dart';

/// Aegis design system — dark-mode, premium, glassmorphic.
/// Each workspace inherits the base theme and overrides the accent color.
class AegisTheme {
  AegisTheme._();

  // ── Base Colors ──
  static const Color surface = Color(0xFF0A0A0F);
  static const Color surfaceContainer = Color(0xFF14141F);
  static const Color surfaceContainerHigh = Color(0xFF1E1E2E);
  static const Color onSurface = Color(0xFFE8E8F0);
  static const Color onSurfaceDim = Color(0xFF8888A0);
  static const Color divider = Color(0xFF2A2A3A);
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF00C9A7);

  /// Builds a workspace-specific ThemeData.
  static ThemeData forWorkspace(AegisWorkspace workspace) {
    return _buildTheme(workspace.accentColor);
  }

  /// The default (workspace selector) theme uses a neutral accent.
  static ThemeData get defaultTheme => _buildTheme(const Color(0xFF6C63FF));

  static ThemeData _buildTheme(Color accent) {
    final colorScheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent.withValues(alpha: 0.7),
      surface: surface,
      onSurface: onSurface,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: divider, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 0.5,
      ),
    );
  }
}
