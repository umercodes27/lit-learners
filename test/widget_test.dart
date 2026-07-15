import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/app.dart';

void main() {
  testWidgets('LittleLearnersApp shows responsive splash and opens login',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalOnError = FlutterError.onError;
    final layoutErrors = <FlutterErrorDetails>[];
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        layoutErrors.add(details);
      } else {
        originalOnError?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(const LittleLearnersApp());
    await tester.pumpAndSettle();

    expect(find.text('LITTLE\nLEARNERS'), findsOneWidget);
    expect(find.text('Play, learn and grow together'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(layoutErrors, isEmpty);

    await tester.tap(find.byKey(const ValueKey('splash-continue-button')));
    await tester.pumpAndSettle();

    expect(find.text('PARENT'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
