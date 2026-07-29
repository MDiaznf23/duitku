import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Class helper untuk membuat M3 Extended Color (Custom Color)
class M3ExtendedColor {
  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;

  const M3ExtendedColor({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  factory M3ExtendedColor.fromBase(Color baseColor, {required bool isDark}) {
    // Membangkitkan Tonal Palette dari warna asal
    final hct = Hct.fromInt(baseColor.value);
    final palette = TonalPalette.of(hct.hue, hct.chroma);

    if (isDark) {
      return M3ExtendedColor(
        color: Color(palette.get(80)),           
        onColor: Color(palette.get(20)),         
        colorContainer: Color(palette.get(30)),  
        onColorContainer: Color(palette.get(90)),
      );
    } else {
      return M3ExtendedColor(
        color: Color(palette.get(40)),           
        onColor: Color(palette.get(100)),
        colorContainer: Color(palette.get(90)),  
        onColorContainer: Color(palette.get(10)),
      );
    }
  }
}

class AppColors {
  final ColorScheme cs;
  late final M3ExtendedColor _success;
  late final M3ExtendedColor _warning;

  AppColors(this.cs) {
    final isDark = cs.brightness == Brightness.dark;

    // Warna dasar extended yang kamu inginkan
    _success = M3ExtendedColor.fromBase(const Color(0xFF3ECF8E), isDark: isDark);
    _warning = M3ExtendedColor.fromBase(const Color(0xFFFBBF24), isDark: isDark);
  }

  // Token M3 Standar
  Color get bg => cs.surface;
  Color get card => cs.surfaceContainer;
  Color get statCard => cs.surfaceContainerHighest;
  Color get border => cs.outlineVariant;
  Color get textMain => cs.onSurface;
  Color get textMuted => cs.onSurfaceVariant;
  Color get accent => cs.primary;
  Color get onAccent => cs.onPrimary;
  Color get accentDark => cs.primaryContainer;
  Color get onAccentDark => cs.onPrimaryContainer;
  Color get muted => cs.surfaceContainerHigh;
  Color get onMuted => cs.onSurface;

  // Role error bawaan M3
  Color get red => cs.error;
  Color get redDark => cs.errorContainer;
  Color get onRed => cs.onError;
  Color get onRedDark => cs.onErrorContainer;

  // Role tonal M3 standar 
  Color get secondary => cs.secondary;
  Color get secondaryDark => cs.secondaryContainer;
  Color get onSecondary => cs.onSecondary;
  Color get onSecondaryDark => cs.onSecondaryContainer;

  Color get tertiary => cs.tertiary;
  Color get tertiaryDark => cs.tertiaryContainer;
  Color get onTertiary => cs.onTertiary;
  Color get onTertiaryDark => cs.onTertiaryContainer;

  // Extended colors yang SEKARANG MURNI MATERIAL 3!
  Color get green => _success.color;
  Color get greenDark => _success.colorContainer;
  Color get onGreen => _success.onColor;
  Color get onGreenDark => _success.onColorContainer;

  Color get yellow => _warning.color;
  Color get yellowDark => _warning.colorContainer;
  Color get onYellow => _warning.onColor;
  Color get onYellowDark => _warning.onColorContainer;
}

/// Akses cepat: `context.colors.textMuted`, dst.
extension AppColorsX on BuildContext {
  AppColors get colors => AppColors(Theme.of(this).colorScheme);
}

ThemeData buildAppTheme({Brightness brightness = Brightness.dark}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C8FFF),
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
