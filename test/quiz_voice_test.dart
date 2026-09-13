import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_option.dart';
import 'package:little_learners/models/module_quiz.dart';
import 'package:little_learners/services/audio/glyph_speech.dart';
import 'package:little_learners/services/audio/quiz_voice.dart';
import 'package:little_learners/views/child_dashboard/module_quiz_page.dart';
import 'package:little_learners/widgets/activities/activity_asset_image.dart';
import 'package:little_learners/widgets/play/play.dart';

/// Records what would have been said, and never reaches a speech engine.
///
/// [GlyphSpeech] talks to a platform channel that does not exist under
/// `flutter test`, so every test here speaks into this instead.
class _FakeSpeech extends GlyphSpeech {
  _FakeSpeech() : super(engine: null);

  final List<String> spoken = [];
  final List<bool> urdu = [];
  int stops = 0;

  @override
  Future<void> speak(String text, {bool urdu = false}) async {
    spoken.add(text);
    this.urdu.add(urdu);
  }

  @override
  Future<void> stop() async => stops++;
}

ModuleQuiz _quizOf(List<ModuleQuizQuestion> questions) =>
    ModuleQuiz(moduleTitle: 'Test', questions: questions);

ModuleQuizQuestion _question({
  required String id,
  String prompt = 'Which one is the ball?',
  bool isRtl = false,
}) {
  return ModuleQuizQuestion(
    id: id,
    prompt: prompt,
    isRtl: isRtl,
    correctIndex: 0,
    options: const [
      ActivityOption(label: 'A', isCorrect: true),
      ActivityOption(label: 'B'),
    ],
  );
}

void main() {
  group('QuizVoice', () {
    test('says a question once, however often the page rebuilds', () {
      final speech = _FakeSpeech();
      final voice = QuizVoice(speech: speech);

      for (var i = 0; i < 5; i++) {
        voice.askQuestion(questionId: 'q1', text: 'Where is the cat?',
            urdu: false);
      }

      expect(speech.spoken, ['Where is the cat?']);
    });

    test('says the next question when the quiz moves on', () {
      final speech = _FakeSpeech();
      final voice = QuizVoice(speech: speech);

      voice.askQuestion(questionId: 'q1', text: 'First?', urdu: false);
      voice.askQuestion(questionId: 'q2', text: 'Second?', urdu: false);

      expect(speech.spoken, ['First?', 'Second?']);
    });

    test('repeats on demand, which is what the button is for', () {
      final speech = _FakeSpeech();
      final voice = QuizVoice(speech: speech);

      voice.askQuestion(questionId: 'q1', text: 'Again?', urdu: false);
      voice.repeatQuestion(text: 'Again?', urdu: false);
      voice.repeatQuestion(text: 'Again?', urdu: false);

      expect(speech.spoken, ['Again?', 'Again?', 'Again?']);
    });

    test('nothing is said for a question with no words', () {
      final speech = _FakeSpeech();
      final voice = QuizVoice(speech: speech);

      voice.askQuestion(questionId: 'q1', text: null, urdu: false);
      voice.askQuestion(questionId: 'q2', text: '   ', urdu: false);

      expect(speech.spoken, isEmpty);
    });

    test('a disposed voice goes quiet', () async {
      final speech = _FakeSpeech();
      final voice = QuizVoice(speech: speech);

      await voice.dispose();
      voice.askQuestion(questionId: 'q1', text: 'Too late', urdu: false);

      expect(speech.spoken, isEmpty);
      expect(speech.stops, 1);
    });

    group('picking the voice', () {
      test('Urdu script is spoken by the Urdu voice', () {
        expect(QuizVoice.urduFor('حرف', levelIsRtl: false), isTrue);
      });

      test('an Urdu level speaks its own prompts in Urdu', () {
        expect(QuizVoice.urduFor('Alif', levelIsRtl: true), isTrue);
      });

      test('an English level stays in English', () {
        expect(QuizVoice.urduFor('Cat', levelIsRtl: false), isFalse);
      });
    });
  });

  group('ModuleQuizPage out loud', () {
    testWidgets('asks the question as the slide appears', (tester) async {
      final speech = _FakeSpeech();

      await tester.pumpWidget(
        MaterialApp(
          home: ModuleQuizPage(
            quiz: _quizOf([_question(id: 'q1')]),
            accent: Colors.blue,
            voice: QuizVoice(speech: speech),
          ),
        ),
      );
      await tester.pump();

      expect(speech.spoken, contains('Which one is the ball?'));
    });

    testWidgets('claps rather than talks over a right answer', (tester) async {
      final speech = _FakeSpeech();

      await tester.pumpWidget(
        MaterialApp(
          home: ModuleQuizPage(
            quiz: _quizOf([_question(id: 'q1')]),
            accent: Colors.blue,
            voice: QuizVoice(speech: speech),
          ),
        ),
      );
      await tester.pump();
      speech.spoken.clear();

      await tester.tap(find.text('A'));
      await tester.pump();

      // The applause and the confetti are the reward; a spoken "well done"
      // on top of them would just compete with the clapping.
      expect(speech.spoken, isEmpty);
      expect(find.byType(ConfettiBurst), findsOneWidget);
    });

    testWidgets('says which one was right after a wrong answer',
        (tester) async {
      final speech = _FakeSpeech();

      await tester.pumpWidget(
        MaterialApp(
          home: ModuleQuizPage(
            quiz: _quizOf([_question(id: 'q1')]),
            accent: Colors.blue,
            voice: QuizVoice(speech: speech),
          ),
        ),
      );
      await tester.pump();
      speech.spoken.clear();

      await tester.tap(find.text('B'));
      await tester.pump();

      expect(speech.spoken, ['The green one is right.']);
      // Nothing to celebrate, so nothing bursts.
      expect(find.byType(ConfettiBurst), findsNothing);
    });

    testWidgets('a pattern question shows the pattern it asks about',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ModuleQuizPage(
            quiz: _quizOf([
              ModuleQuizQuestion(
                id: 'p1',
                prompt: 'What comes next?',
                promptSequence: const [
                  'assets/img/a.png',
                  'assets/img/b.png',
                  'assets/img/a.png',
                ],
                correctIndex: 0,
                options: const [
                  ActivityOption(label: 'A', isCorrect: true),
                  ActivityOption(label: 'B'),
                ],
              ),
            ]),
            accent: Colors.blue,
            voice: QuizVoice(speech: _FakeSpeech()),
          ),
        ),
      );
      await tester.pump();

      // Without the sequence on screen this slide is a coin toss between two
      // shapes, which is what it was.
      expect(find.byType(ActivityAssetImage), findsNWidgets(3));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('an Urdu question uses the Urdu voice', (tester) async {
      final speech = _FakeSpeech();

      await tester.pumpWidget(
        MaterialApp(
          home: ModuleQuizPage(
            quiz: _quizOf([
              _question(id: 'q1', prompt: 'یہ کیا ہے؟', isRtl: true),
            ]),
            accent: Colors.blue,
            voice: QuizVoice(speech: speech),
          ),
        ),
      );
      await tester.pump();

      expect(speech.urdu.first, isTrue);
    });
  });
}
