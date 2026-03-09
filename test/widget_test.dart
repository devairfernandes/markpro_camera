import 'package:flutter_test/flutter_test.dart';
import 'package:marktime_app/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TimemarkApp(cameras: []));

    // Verify that our app starts.
    expect(find.text('MARKTIME'), findsOneWidget);
  });
}
