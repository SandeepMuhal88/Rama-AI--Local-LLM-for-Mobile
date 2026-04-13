import 'package:flutter_test/flutter_test.dart';
import 'package:rama_ai/main.dart';
import 'package:rama_ai/core/app_theme.dart';

void main() {
  testWidgets('RAMA AI smoke test', (WidgetTester tester) async {
    appTheme = AppTheme(isDark: true, accent: kAccentPresets[0]);
    await tester.pumpWidget(RamaApp(theme: appTheme));
    await tester.pumpAndSettle();
  });
}
