import 'activity_option.dart';

/// One slide of a module's closing quiz.
///
/// Deliberately not [QuizQuestion]: that one is text-only, and the age packs
/// are mostly pictures. Carrying [ActivityOption]s instead means a quiz slide
/// renders the same letters, glyphs and artwork the child just played with,
/// rather than the labels someone would have had to write for them.
class ModuleQuizQuestion {
  const ModuleQuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.promptImage,
    this.promptRepeat = 1,
    this.isRtl = false,
  });

  final String id;

  /// What the child is asked. Falls back to a phrasing for the component when
  /// the pack item carried only an audio prompt.
  final String prompt;

  /// Shown above the options when the question is "which of these matches
  /// *this*" — the shadow-match and identify rounds.
  final String? promptImage;

  /// How many copies of [promptImage] to draw. Counting questions ask "how
  /// many do you see?", which needs the picture repeated rather than described.
  final int promptRepeat;

  final List<ActivityOption> options;
  final int correctIndex;

  /// Urdu questions read right-to-left, like the module they came from.
  final bool isRtl;

  bool isCorrect(int index) => index == correctIndex;
}

/// The quiz that closes a module, assembled from that module's own activities.
class ModuleQuiz {
  const ModuleQuiz({
    required this.moduleTitle,
    required this.questions,
  });

  const ModuleQuiz.empty()
      : moduleTitle = '',
        questions = const [];

  /// Half right is a pass.
  ///
  /// These are two- and three-year-olds and the quiz is a victory lap over
  /// content they have already tapped through, not a gate. A bar set where
  /// half the answers carry it keeps the badge worth having without turning a
  /// single mis-tap into a failure.
  static const passingPercent = 50;

  /// How many slides a quiz aims for, and the fewest that make one worth
  /// offering. Below [minQuestions] the module simply has no quiz rather than
  /// a two-question one where a single slip is a fail.
  static const targetQuestions = 5;
  /// Two is a quiz; nothing is not.
  ///
  /// At three, a module whose activities yield only two usable rounds showed
  /// no trophy at all — the age-3 Urdu module is exactly that, two letter-and-
  /// picture pairs and two tracing levels that ask nothing. A child who
  /// finished every level was told, silently, that there was nothing at the
  /// end of the road. Passing is a proportion, so a two-slide quiz still has
  /// to be more than half right.
  static const minQuestions = 2;

  final String moduleTitle;
  final List<ModuleQuizQuestion> questions;

  int get length => questions.length;
  bool get isEmpty => questions.isEmpty;

  /// Percentage for [correct] right answers, rounded to a whole number.
  int percentFor(int correct) {
    if (questions.isEmpty) return 0;
    return ((correct / questions.length) * 100).round();
  }

  bool passes(int correct) => percentFor(correct) >= passingPercent;
}
