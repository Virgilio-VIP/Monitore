import 'package:flutter_test/flutter_test.dart';
import 'package:maria_maia/main.dart';

void main() {
  testWidgets('App should load splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MariaMaiaApp());

    // Verify splash screen elements
    expect(find.text('MariaMaia'), findsOneWidget);
    expect(find.text('Gestor de Pecuária Pro'), findsOneWidget);
  });
}
