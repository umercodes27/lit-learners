import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/widgets/module_card.dart';

void main() {
  testWidgets('ModuleCard stays within a compact two-column grid cell',
      (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 138,
              height: 166,
              child: ModuleCard(
                module: const LearningModule(
                  id: 'english',
                  title: 'Letters and Sounds',
                  description: 'Listen, speak, trace, and discover new words.',
                  category: ModuleCategory.english,
                  minStage: 1,
                  maxStage: 3,
                  order: 1,
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Letters and Sounds'), findsOneWidget);
    expect(layoutErrors, isEmpty);
  });
}
