import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/main.dart';

void main() {
  testWidgets('Finance Tracker app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FinanceTrackerApp());

    // Verify that the app title is present
    expect(find.text('Finance Tracker'), findsOneWidget);
  });
}
