import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/app/app.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const TimeWayProApp());
    expect(find.text('时途'), findsOneWidget);
  });
}
