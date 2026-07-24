import 'package:flutter_test/flutter_test.dart';
import 'package:app_patente_taiwanese/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    
    // Just verify the app builds without crashing.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
