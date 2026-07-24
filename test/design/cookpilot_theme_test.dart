import 'package:cookpilot/design/cookpilot_colors.dart';
import 'package:cookpilot/design/cookpilot_theme.dart';
import 'package:cookpilot/design/cookpilot_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DESIGN.md 색상 토큰을 명시적으로 사용한다', () {
    final theme = CookPilotTheme.light;

    expect(theme.colorScheme.primary, CookPilotColors.primary);
    expect(theme.colorScheme.primary, const Color(0xFF2E558F));
    expect(theme.colorScheme.primaryContainer, const Color(0xFFD5E2F6));
    expect(theme.colorScheme.inverseSurface, const Color(0xFF04070E));
    expect(theme.colorScheme.inversePrimary, const Color(0xFF90B3E7));
    expect(theme.colorScheme.error, const Color(0xFFAC1C0F));

    final semantic = theme.extension<CookPilotSemanticColors>();
    expect(semantic, isNotNull);
    expect(semantic!.focus, const Color(0xFFDD7D00));
    expect(semantic.success, const Color(0xFF195C2E));
  });
}
