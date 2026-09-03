import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_pack.dart';
import 'package:little_learners/models/module_quiz.dart';
import 'package:little_learners/services/content/module_quiz_builder.dart';

ActivityPack _load(String path) {
  final raw = File(path).readAsStringSync();
  return ActivityPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  final packs = {
    2: _load('assets/age2/little-learners-age2-data.json'),
    3: _load('assets/age3/little-learners-age3-data.json'),
  };

  group('module quizzes build from real pack content', () {
    for (final entry in packs.entries) {
      for (final module in entry.value.modules) {
        test('age ${entry.key} / ${module.key}', () {
          final quiz = ModuleQuizBuilder.build(module);

          // Reported so the run shows what each module actually produced,
          // including the modules that legitimately get no quiz.
          printOnFailure('questions: ${quiz.length}');
          // ignore: avoid_print
          print('age ${entry.key} ${module.key.padRight(14)} '
              '-> ${quiz.length} questions');

          if (quiz.isEmpty) return;

          expect(quiz.length, greaterThanOrEqualTo(ModuleQuiz.minQuestions));
          expect(quiz.length, lessThanOrEqualTo(ModuleQuiz.targetQuestions));

          for (final question in quiz.questions) {
            expect(question.options.length, greaterThanOrEqualTo(2));
            expect(question.correctIndex, greaterThanOrEqualTo(0));
            expect(question.correctIndex, lessThan(question.options.length));
            expect(question.prompt.trim(), isNotEmpty);
            // Every option must be renderable as text or a picture.
            for (final option in question.options) {
              expect(
                option.label != null || option.image != null,
                isTrue,
                reason: 'option in "${question.prompt}" has nothing to show',
              );
            }
          }

          // Exactly one right answer per slide.
          for (final question in quiz.questions) {
            expect(
              question.options.where((o) => o.isCorrect).length,
              1,
              reason: 'question "${question.prompt}" must have one winner',
            );
          }
        });
      }
    }
  });

  test('passing bar is 50 percent', () {
    const quiz = ModuleQuiz(moduleTitle: 'x', questions: []);
    expect(ModuleQuiz.passingPercent, 50);

    // 5-question quiz: 2 right fails, 3 right passes.
    final five = ModuleQuiz(
      moduleTitle: 'five',
      questions: List.filled(5, _stub),
    );
    expect(five.percentFor(2), 40);
    expect(five.passes(2), isFalse);
    expect(five.percentFor(3), 60);
    expect(five.passes(3), isTrue);

    // 4-question quiz: exactly half passes.
    final four = ModuleQuiz(
      moduleTitle: 'four',
      questions: List.filled(4, _stub),
    );
    expect(four.percentFor(2), 50);
    expect(four.passes(2), isTrue);

    expect(quiz.percentFor(0), 0);
  });
}

const _stub = ModuleQuizQuestion(
  id: 'stub',
  prompt: 'stub',
  options: [],
  correctIndex: 0,
);

