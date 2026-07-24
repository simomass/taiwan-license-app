import 'package:app_patente_taiwanese/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
