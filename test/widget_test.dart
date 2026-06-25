import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/app.dart';

void main() {
  testWidgets('LittleLearnersApp shows splash shell', (tester) async {
    await tester.pumpWidget(const LittleLearnersApp());

    expect(find.text('Little Learners'), findsOneWidget);
  });
}
