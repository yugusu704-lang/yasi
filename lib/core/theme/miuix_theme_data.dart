import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'app_colors.dart';

class AppMiuixTheme {
  AppMiuixTheme._();

  static MiuixThemeData lightTheme() {
    final base = miuixColorsFromSeed(
      seed: AppColors.ieltsCrimson,
      dark: false,
    );

    final customizedColors = base.copy(
      primary: AppColors.ieltsCrimson,
      onPrimary: Colors.white,
      primaryContainer: AppColors.ieltsCrimson.withValues(alpha: 0.12),
      onPrimaryContainer: AppColors.ieltsCrimson,
      secondary: AppColors.oxfordNavy,
      onSecondary: Colors.white,
      background: AppColors.paperBackground,
      onBackground: AppColors.textPrimary,
      surface: AppColors.paperBackground,
      onSurface: AppColors.textPrimary,
      surfaceContainer: AppColors.paperSurface,
      onSurfaceContainer: AppColors.textPrimary,
      surfaceContainerHigh: AppColors.cardSurface,
      dividerLine: AppColors.borderLight,
    );

    return MiuixThemeData.light(
      colors: customizedColors,
    );
  }

  static MiuixThemeData darkTheme() {
    final base = miuixColorsFromSeed(
      seed: AppColors.ieltsCrimson,
      dark: true,
    );
    return MiuixThemeData.dark(colors: base);
  }
}
