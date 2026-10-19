import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_expense_tracker/main.dart';

void main() {
  testWidgets('VKU Expense App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VKUExpenseApp());
    expect(find.text('VKU Expense Tracker'), findsOneWidget);
  });
}
