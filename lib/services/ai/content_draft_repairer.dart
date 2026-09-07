import '../../models/content_item.dart';
import '../../models/learning_level.dart';
import '../../models/quiz_question.dart';
import '../../models/video_lesson.dart';
import 'content_draft_validator.dart';

/// A level after the obvious problems were fixed, and a plain-English note
/// for each fix so the admin can see what changed.
class RepairedLevel {
  const RepairedLevel({required this.level, required this.notes});

  final LearningLevel level;

  /// One line per change, written for the review screen. Never empty when
  /// something was altered — a silent repair is worse than no repair.
  final List<String> notes;

  bool get changed => notes.isNotEmpty;
}

/// Fixes what has exactly one right answer, and refuses to touch anything
/// else.
///
/// The line is not "can I make this valid?" — it is "is there only one thing
/// this could have meant?". A passing score of 85 on a drawing level can only
/// have meant a score inside the band, so it is clamped. A `correctIndex` of 3
/// against three options could have meant any of them, so it is left alone and
/// blocks.
///
/// That distinction matters more here than it would in the hand-typed form.
/// `AdminContentViewModel` clamps `correctIndex` today, which is reasonable
/// when a person typed the number and can see the result on screen. Doing the
/// same to generated content would quietly invent an answer and then teach it
/// to a toddler as fact.
class ContentDraftRepairer {
  const ContentDraftRepairer();

  static final RegExp _durationLabel = RegExp(r'^\d{1,2}:\d{2}$');
  static const _defaultDuration = '0:30';

  RepairedLevel repair(LearningLevel level) {
    final notes = <String>[];
    var repaired = level;

    repaired = _passingScore(repaired, notes);
    repaired = _contentItems(repaired, notes);
    repaired = _quizQuestions(repaired, notes);
    repaired = _videoLessons(repaired, notes);

    return RepairedLevel(level: repaired, notes: notes);
  }

  LearningLevel _passingScore(LearningLevel level, List<String> notes) {
    final isCanvas =
        level.type == LevelType.drawing || level.type == LevelType.tracing;

    final low = isCanvas ? ContentDraftValidator.canvasMinPassingScore : 0;
    final high = isCanvas ? ContentDraftValidator.canvasMaxPassingScore : 100;

    if (level.passingScore >= low && level.passingScore <= high) return level;

    final clamped = level.passingScore.clamp(low, high);
    notes.add(isCanvas
        ? 'Passing score ${level.passingScore} → $clamped. A grown-up '
            'grades ${level.type.name} levels, and the four grades only work '
            'out to one failure between $low and $high.'
        : 'Passing score ${level.passingScore} → $clamped, to stay inside '
            '0-100.');
    return level.copyWith(passingScore: clamped);
  }

  /// The only card repair: a missing picture description falls back to the
  /// card's own title. Every other field carries meaning that cannot be
  /// guessed, so a blank one blocks instead.
  LearningLevel _contentItems(LearningLevel level, List<String> notes) {
    if (level.contentItems.isEmpty) return level;

    var fixed = 0;
    final items = <ContentItem>[];
    for (final item in level.contentItems) {
      if (item.visualLabel.trim().isEmpty && item.title.trim().isNotEmpty) {
        fixed++;
        items.add(ContentItem(
          title: item.title,
          prompt: item.prompt,
          displayText: item.displayText,
          visualLabel: item.title,
          audioCueKey: item.audioCueKey,
        ));
      } else {
        items.add(item);
      }
    }

    if (fixed == 0) return level;
    notes.add('Filled in $fixed missing picture '
        '${fixed == 1 ? "description" : "descriptions"} from the card title.');
    return level.copyWith(contentItems: items);
  }

  /// A question with fewer than two options is not a question. It is dropped
  /// rather than padded, because inventing a wrong answer to choose between
  /// is inventing content.
  LearningLevel _quizQuestions(LearningLevel level, List<String> notes) {
    if (level.quizQuestions.isEmpty) return level;

    final kept = <QuizQuestion>[
      for (final q in level.quizQuestions)
        if (q.options.where((o) => o.trim().isNotEmpty).length >= 2) q,
    ];

    if (kept.length == level.quizQuestions.length) return level;
    final dropped = level.quizQuestions.length - kept.length;
    notes.add('Dropped $dropped quiz '
        '${dropped == 1 ? "question that had" : "questions that had"} fewer '
        'than two answers to choose from.');
    return level.copyWith(quizQuestions: kept);
  }

  LearningLevel _videoLessons(LearningLevel level, List<String> notes) {
    if (level.videoLessons.isEmpty) return level;

    var fixed = 0;
    final lessons = <VideoLesson>[];
    for (final lesson in level.videoLessons) {
      if (_durationLabel.hasMatch(lesson.durationLabel.trim())) {
        lessons.add(lesson);
        continue;
      }
      fixed++;
      lessons.add(VideoLesson(
        id: lesson.id,
        title: lesson.title,
        description: lesson.description,
        durationLabel: _defaultDuration,
        videoUrl: lesson.videoUrl,
        thumbnailLabel: lesson.thumbnailLabel,
      ));
    }

    if (fixed == 0) return level;
    notes.add('Set $fixed video '
        '${fixed == 1 ? "duration" : "durations"} to $_defaultDuration, which '
        'is a label only.');
    return level.copyWith(videoLessons: lessons);
  }
}
