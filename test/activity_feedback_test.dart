import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/models/activity_option.dart';
import 'package:little_learners/widgets/activities/activity_feedback_controller.dart';
import 'package:little_learners/widgets/activities/activity_player.dart';
import 'package:little_learners/widgets/activities/activity_audio.dart';
import 'package:little_learners/widgets/activities/correct_feedback_animation.dart';
import 'package:little_learners/widgets/activities/try_again_feedback_animation.dart';

/// The feedback animations, and the wiring that guarantees every component
/// gets them.
void main() {
  group('CorrectFeedbackAnimation', () {
    testWidgets('draws nothing until the pulse fires', (tester) async {
      final pulse = ValueNotifier<int>(0);
      addTearDown(pulse.dispose);

      await tester.pumpWidget(MaterialApp(
        home: CorrectFeedbackAnimation(pulse: pulse),
      ));

      expect(find.byKey(CorrectFeedbackAnimation.paintKey), findsNothing);
    });

    testWidgets('paints confetti after a pulse and clears when done',
        (tester) async {
      final pulse = ValueNotifier<int>(0);
      addTearDown(pulse.dispose);

      await tester.pumpWidget(MaterialApp(
        home: CorrectFeedbackAnimation(
          pulse: pulse,
          duration: const Duration(milliseconds: 600),
        ),
      ));

      pulse.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(CorrectFeedbackAnimation.paintKey), findsOneWidget,
          reason: 'confetti should be painting mid-burst');

      // Runs to completion and leaves the screen clear for the next round.
      await tester.pumpAndSettle();
      expect(find.byKey(CorrectFeedbackAnimation.paintKey), findsNothing);
    });

    testWidgets('can fire again for the next round', (tester) async {
      final pulse = ValueNotifier<int>(0);
      addTearDown(pulse.dispose);

      await tester.pumpWidget(MaterialApp(
        home: CorrectFeedbackAnimation(
          pulse: pulse,
          duration: const Duration(milliseconds: 400),
        ),
      ));

      for (var round = 0; round < 3; round++) {
        pulse.value++;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(CorrectFeedbackAnimation.paintKey), findsOneWidget,
            reason: 'burst $round did not play');
        await tester.pumpAndSettle();
      }
    });

    testWidgets('never intercepts a tap', (tester) async {
      final pulse = ValueNotifier<int>(0);
      addTearDown(pulse.dispose);
      var taps = 0;

      await tester.pumpWidget(MaterialApp(
        home: Stack(children: [
          GestureDetector(
            onTap: () => taps++,
            child: const SizedBox.expand(child: ColoredBox(color: Colors.white)),
          ),
          CorrectFeedbackAnimation(pulse: pulse),
        ]),
      ));

      pulse.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();

      expect(taps, 1, reason: 'the overlay swallowed the tap');
      await tester.pumpAndSettle();
    });
  });

  group('TryAgainFeedbackAnimation', () {
    testWidgets('shows a gentle question mark, then fades', (tester) async {
      final pulse = ValueNotifier<int>(0);
      addTearDown(pulse.dispose);

      await tester.pumpWidget(MaterialApp(
        home: TryAgainFeedbackAnimation(
          pulse: pulse,
          duration: const Duration(milliseconds: 500),
        ),
      ));
      expect(find.text('?'), findsNothing);

      pulse.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('?'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('?'), findsNothing);
    });

    testWidgets('is amber, never red', (tester) async {
      final pulse = ValueNotifier<int>(0);
      addTearDown(pulse.dispose);

      await tester.pumpWidget(MaterialApp(
        home: TryAgainFeedbackAnimation(pulse: pulse),
      ));
      pulse.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final mark = tester.widget<Text>(find.text('?'));
      final colour = mark.style!.color!;
      // Warm hue, and not the harsh red a toddler would read as failure.
      expect(colour.g, greaterThan(0.5), reason: 'should be amber, not red');
      await tester.pumpAndSettle();
    });
  });

  group('ActivityFeedbackController', () {
    test('celebrate and tryAgain each bump only their own pulse', () {
      final controller = ActivityFeedbackController();
      addTearDown(controller.dispose);

      expect(controller.correctPulse.value, 0);
      expect(controller.tryAgainPulse.value, 0);

      controller.celebrate();
      expect(controller.correctPulse.value, 1);
      expect(controller.tryAgainPulse.value, 0);

      controller.tryAgain();
      expect(controller.correctPulse.value, 1);
      expect(controller.tryAgainPulse.value, 1);
    });
  });

  group('components wire the feedback in', () {
    ActivityData twoChoice() => const TwoChoiceTapData(
          title: 'T',
          isRtl: false,
          items: [
            TwoChoiceTapItem(
              options: [
                ActivityOption(label: 'A', isCorrect: true),
                ActivityOption(label: 'B'),
              ],
            ),
          ],
        );

    testWidgets('a right tap bursts confetti and no question mark',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActivityPlayer(data: twoChoice(), audio: ActivityAudio()),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(CorrectFeedbackAnimation.paintKey), findsOneWidget);
      expect(find.text('?'), findsNothing);

      // Explicit pumps rather than pumpAndSettle: the mascot bobs forever by
      // design, so the tree never reaches a resting state.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a wrong tap shows the question mark, no confetti',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActivityPlayer(data: twoChoice(), audio: ActivityAudio()),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('B'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('?'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });
  });
}
