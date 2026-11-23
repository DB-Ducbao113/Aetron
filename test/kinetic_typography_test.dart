import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kinetic typography', () {
    test('uses BeVietnamPro for display and telemetry styles with tabular figures', () {
      expect(KineticTypography.displayFontFamily, 'BeVietnamPro');
      expect(
        [
          KineticTypography.metricHero,
          KineticTypography.metricMedium,
          KineticTypography.displayLarge,
          KineticTypography.headlineLarge,
          KineticTypography.pageTitle,
          KineticTypography.label,
        ].map((style) => style.fontFamily),
        everyElement(KineticTypography.displayFontFamily),
      );
      expect(
        KineticTypography.metricHero.fontFeatures,
        KineticTypography.tabularFigures,
      );
    });

    test('uses BeVietnamPro for Vietnamese body copy', () {
      expect(KineticTypography.bodyFontFamily, 'BeVietnamPro');
      expect(
        [
          KineticTypography.bodyLarge,
          KineticTypography.bodyMedium,
          KineticTypography.bodySmall,
          KineticTypography.caption,
          KineticTypography.greeting,
        ].map((style) => style.fontFamily),
        everyElement(KineticTypography.bodyFontFamily),
      );
    });

    test('uses bold weights for prominent styles', () {
      expect(KineticTypography.metricHero.fontWeight, FontWeight.w800);
      expect(KineticTypography.displayLarge.fontWeight, FontWeight.w700);
      expect(KineticTypography.pageTitle.fontWeight, FontWeight.w800);
    });

    test('defaults unstyled app text to BeVietnamPro in light and dark themes', () {
      for (final brightness in Brightness.values) {
        final theme = KineticTheme.buildTheme(brightness);
        expect(theme.textTheme.bodyMedium?.fontFamily, 'BeVietnamPro');
        expect(theme.primaryTextTheme.bodyMedium?.fontFamily, 'BeVietnamPro');
      }
    });
  });
}
