import '../models/content_item.dart';
import '../core/utils/age_stage_helper.dart';
import '../models/learning_level.dart';
import '../models/learning_module.dart';
import '../models/quiz_question.dart';
import '../models/video_lesson.dart';

/// Stamp for the bundled content below.
///
/// The local database is seeded once and then read from, so edits here would
/// otherwise never reach a device that already ran the app. Bumping this string
/// makes the content repository reinstall the bundle on next launch, keeping
/// progress and downloaded flags intact.
///
/// **Bump this whenever you add, remove or edit anything in this file.**
const bundledContentRevision = '2026-09-10-video-without-quizzes';

const seedModules = <LearningModule>[
  LearningModule(
    id: 'math',
    title: 'Math',
    description: 'Numbers, counting, and shapes.',
    category: ModuleCategory.math,
    minStage: 2,
    maxStage: 4,
    order: 1,
  ),
  LearningModule(
    id: 'english',
    title: 'English',
    description: 'Letters, sounds, and simple words.',
    category: ModuleCategory.english,
    minStage: 2,
    maxStage: 4,
    order: 2,
  ),
  LearningModule(
    id: 'urdu',
    title: 'اردو',
    description: 'حروف، آوازیں، اور آسان الفاظ۔',
    category: ModuleCategory.urdu,
    minStage: 2,
    maxStage: 4,
    order: 3,
  ),
  LearningModule(
    id: 'video',
    title: 'Video Learning',
    description: 'Short guided lessons with parent-friendly pacing.',
    category: ModuleCategory.video,
    minStage: 2,
    maxStage: 4,
    order: 4,
  ),
  LearningModule(
    id: 'logic',
    title: 'Logic',
    description: 'Patterns, sorting, and tiny thinking puzzles.',
    category: ModuleCategory.logic,
    minStage: 2,
    maxStage: 4,
    order: 5,
  ),
  LearningModule(
    id: 'story',
    title: 'Stories',
    description: 'Picture stories with gentle narration.',
    category: ModuleCategory.story,
    minStage: 2,
    maxStage: 4,
    order: 6,
  ),
  LearningModule(
    id: 'drawing',
    title: 'Drawing',
    description: 'Free drawing and coloring activities.',
    category: ModuleCategory.drawing,
    minStage: 2,
    maxStage: 4,
    order: 7,
  ),
  // Starts at stage 2: following a dotted line needs steadier hands than a
  // one-year-old has.
  LearningModule(
    id: 'tracing',
    title: 'Tracing',
    description: 'Trace letters and numbers along dotted guides.',
    category: ModuleCategory.tracing,
    minStage: 2,
    maxStage: 4,
    order: 8,
  ),
];

/// Every level the app ships with.
///
/// A module is a ladder of levels, each covering one **portion** of that
/// module's sequence — `A – F`, then `G – L`, and so on. Inside a level the
/// content items are walked in order, so a child meets A before B before C.
/// The same portions repeat at every age stage; what changes is the activity
/// and the wording, so a birthday moves a child up to a harder pass over
/// letters they already recognise.
final seedLevels = <LearningLevel>[
  ..._englishAlphabetLevels(),
  ..._authoredLevels,
];

const _authoredLevels = <LearningLevel>[
  LearningLevel(
    id: 'math-stage3-1',
    portionLabel: '1 – 5',
    moduleId: 'math',
    stage: 3,
    levelNumber: 1,
    title: 'Count to 5',
    subtitle: 'Practice counting small groups.',
    type: LevelType.counting,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Three',
        prompt: 'Count three apples.',
        displayText: '3',
        visualLabel: 'Three apples',
      ),
      ContentItem(
        title: 'Five',
        prompt: 'Count five stars.',
        displayText: '5',
        visualLabel: 'Five stars',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'math-q1',
        prompt: 'How many apples are in this group?',
        options: ['2', '3', '4'],
        correctIndex: 1,
        visualLabel: 'Three apples',
        explanation: 'There are three apples.',
      ),
      QuizQuestion(
        id: 'math-q2',
        prompt: 'Which number comes after 4?',
        options: ['3', '5', '7'],
        correctIndex: 1,
        explanation: 'Five comes after four.',
      ),
    ],
  ),
  LearningLevel(
    id: 'math-stage3-2',
    moduleId: 'math',
    stage: 3,
    levelNumber: 2,
    title: 'Shape Hunt',
    subtitle: 'Find circles, squares, and triangles.',
    type: LevelType.matching,
    passingScore: 70,
    isBundled: false,
    contentItems: [
      ContentItem(
        title: 'Circle',
        prompt: 'Find something round.',
        displayText: 'O',
        visualLabel: 'Circle',
      ),
      ContentItem(
        title: 'Triangle',
        prompt: 'Find the shape with three sides.',
        displayText: '△',
        visualLabel: 'Triangle',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'math-shape-q1',
        prompt: 'Which shape has three sides?',
        options: ['Circle', 'Square', 'Triangle'],
        correctIndex: 2,
      ),
    ],
  ),
  LearningLevel(
    id: 'urdu-stage2-1',
    portionLabel: 'ا – ب',
    moduleId: 'urdu',
    stage: 2,
    levelNumber: 1,
    title: 'ا اور ب',
    subtitle: 'دو حروف پہچانیں اور ان کی آوازیں دہرائیں۔',
    type: LevelType.flashcards,
    passingScore: 65,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'ا',
        prompt: 'یہ ا ہے۔ ا سے انار۔',
        displayText: 'ا',
        visualLabel: 'حرف ا',
        audioCueKey: 'urdu_alif',
      ),
      ContentItem(
        title: 'ب',
        prompt: 'یہ ب ہے۔ ب سے بکری۔',
        displayText: 'ب',
        visualLabel: 'حرف ب',
        audioCueKey: 'urdu_bay',
      ),
      ContentItem(
        title: 'بکری',
        prompt: 'ب سے بکری۔ لفظ کو دہرائیں۔',
        displayText: 'بکری',
        visualLabel: 'بکری کا لفظی کارڈ',
        audioCueKey: 'urdu_bakri',
      ),
    ],
  ),
  LearningLevel(
    id: 'urdu-stage3-1',
    portionLabel: 'ا – پ',
    moduleId: 'urdu',
    stage: 3,
    levelNumber: 1,
    title: 'حروف ا ب پ',
    subtitle: 'حروف کو لفظوں سے ملائیں۔',
    type: LevelType.flashcards,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'ا',
        prompt: 'ا سے انار۔',
        displayText: 'ا',
        visualLabel: 'انار',
        audioCueKey: 'urdu_alif',
      ),
      ContentItem(
        title: 'ب',
        prompt: 'ب سے بکری۔',
        displayText: 'ب',
        visualLabel: 'بکری',
        audioCueKey: 'urdu_bay',
      ),
      ContentItem(
        title: 'پ',
        prompt: 'پ سے پتنگ۔',
        displayText: 'پ',
        visualLabel: 'پتنگ',
        audioCueKey: 'urdu_pay',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'urdu-alif-q1',
        prompt: 'کون سا حرف انار سے شروع ہوتا ہے؟',
        options: ['ا', 'ب', 'پ'],
        correctIndex: 0,
        explanation: 'انار ا سے شروع ہوتا ہے۔',
      ),
      QuizQuestion(
        id: 'urdu-bay-q1',
        prompt: 'بکری کس حرف سے شروع ہوتی ہے؟',
        options: ['پ', 'ا', 'ب'],
        correctIndex: 2,
        explanation: 'بکری ب سے شروع ہوتی ہے۔',
      ),
    ],
  ),
  LearningLevel(
    id: 'urdu-stage3-2',
    moduleId: 'urdu',
    stage: 3,
    levelNumber: 2,
    title: 'لفظ ملائیں',
    subtitle: 'حرف کو درست لفظ کے ساتھ ملائیں۔',
    type: LevelType.matching,
    passingScore: 70,
    isBundled: false,
    contentItems: [
      ContentItem(
        title: 'انار',
        prompt: 'ا سے شروع ہونے والا لفظ چنیں۔',
        displayText: 'ا',
        visualLabel: 'ا - انار',
        audioCueKey: 'urdu_anaar',
      ),
      ContentItem(
        title: 'بکری',
        prompt: 'ب سے شروع ہونے والا لفظ چنیں۔',
        displayText: 'ب',
        visualLabel: 'ب - بکری',
        audioCueKey: 'urdu_bakri',
      ),
      ContentItem(
        title: 'پتنگ',
        prompt: 'پ سے شروع ہونے والا لفظ چنیں۔',
        displayText: 'پ',
        visualLabel: 'پ - پتنگ',
        audioCueKey: 'urdu_patang',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'urdu-match-q1',
        prompt: 'پ سے کون سا لفظ بنتا ہے؟',
        options: ['انار', 'بکری', 'پتنگ'],
        correctIndex: 2,
      ),
    ],
  ),
  LearningLevel(
    id: 'urdu-stage4-1',
    moduleId: 'urdu',
    stage: 4,
    levelNumber: 1,
    title: 'آسان الفاظ',
    subtitle: 'حروف پڑھیں اور چھوٹے لفظ پہچانیں۔',
    type: LevelType.matching,
    passingScore: 75,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'آم',
        prompt: 'آ سے آم۔ درست لفظ چنیں۔',
        displayText: 'آ',
        visualLabel: 'آم',
        audioCueKey: 'urdu_aam',
      ),
      ContentItem(
        title: 'بابا',
        prompt: 'ب سے بابا۔ درست لفظ چنیں۔',
        displayText: 'ب',
        visualLabel: 'بابا',
        audioCueKey: 'urdu_baba',
      ),
      ContentItem(
        title: 'پانی',
        prompt: 'پ سے پانی۔ درست لفظ چنیں۔',
        displayText: 'پ',
        visualLabel: 'پانی',
        audioCueKey: 'urdu_pani',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'urdu-stage4-q1',
        prompt: 'آم کس حرف سے شروع ہوتا ہے؟',
        options: ['آ', 'ب', 'پ'],
        correctIndex: 0,
      ),
      QuizQuestion(
        id: 'urdu-stage4-q2',
        prompt: 'پانی کس حرف سے شروع ہوتا ہے؟',
        options: ['ب', 'پ', 'ا'],
        correctIndex: 1,
      ),
    ],
  ),
  LearningLevel(
    id: 'logic-stage2-1',
    moduleId: 'logic',
    stage: 2,
    levelNumber: 1,
    title: 'Big and Small',
    subtitle: 'Compare sizes and choose the matching idea.',
    type: LevelType.matching,
    passingScore: 65,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Big',
        prompt: 'Choose big for the large block.',
        displayText: 'Big',
        visualLabel: 'Large block',
        audioCueKey: 'logic_big',
      ),
      ContentItem(
        title: 'Small',
        prompt: 'Choose small for the tiny block.',
        displayText: 'Small',
        visualLabel: 'Tiny block',
        audioCueKey: 'logic_small',
      ),
      ContentItem(
        title: 'Same',
        prompt: 'Choose same when two blocks match.',
        displayText: 'Same',
        visualLabel: 'Matching blocks',
        audioCueKey: 'logic_same',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'logic-size-q1',
        prompt: 'Which word means two things match?',
        options: ['Same', 'Big', 'Small'],
        correctIndex: 0,
        explanation: 'Same means they match.',
      ),
    ],
  ),
  LearningLevel(
    id: 'logic-stage3-1',
    moduleId: 'logic',
    stage: 3,
    levelNumber: 1,
    title: 'Color Patterns',
    subtitle: 'Look at what repeats and choose what comes next.',
    type: LevelType.matching,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Blue',
        prompt: 'Red, blue, red. What comes next?',
        displayText: 'R B R _',
        visualLabel: 'Red blue red blue pattern',
        audioCueKey: 'logic_blue',
      ),
      ContentItem(
        title: 'Green',
        prompt: 'Yellow, green, yellow. What comes next?',
        displayText: 'Y G Y _',
        visualLabel: 'Yellow green yellow green pattern',
        audioCueKey: 'logic_green',
      ),
      ContentItem(
        title: 'Square',
        prompt: 'Circle, square, circle. What comes next?',
        displayText: 'O □ O _',
        visualLabel: 'Circle square circle square pattern',
        audioCueKey: 'logic_square',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'logic-pattern-q1',
        prompt: 'Red, blue, red. What comes next?',
        options: ['Blue', 'Red', 'Yellow'],
        correctIndex: 0,
        explanation: 'The colors repeat red, blue, red, blue.',
      ),
      QuizQuestion(
        id: 'logic-pattern-q2',
        prompt: 'Circle, square, circle. What shape comes next?',
        options: ['Triangle', 'Circle', 'Square'],
        correctIndex: 2,
        explanation: 'The pattern repeats circle, square.',
      ),
    ],
  ),
  LearningLevel(
    id: 'logic-stage3-2',
    moduleId: 'logic',
    stage: 3,
    levelNumber: 2,
    title: 'Sort the Toys',
    subtitle: 'Group things by color, shape, and kind.',
    type: LevelType.matching,
    passingScore: 70,
    isBundled: false,
    contentItems: [
      ContentItem(
        title: 'Color',
        prompt: 'Sort the red toys together.',
        displayText: 'Color',
        visualLabel: 'Red toys together',
        audioCueKey: 'logic_color',
      ),
      ContentItem(
        title: 'Shape',
        prompt: 'Sort the round toys together.',
        displayText: 'Shape',
        visualLabel: 'Round toys together',
        audioCueKey: 'logic_shape',
      ),
      ContentItem(
        title: 'Kind',
        prompt: 'Sort cars with cars and blocks with blocks.',
        displayText: 'Kind',
        visualLabel: 'Toy groups by kind',
        audioCueKey: 'logic_kind',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'logic-sort-q1',
        prompt: 'If all red toys go together, what are we sorting by?',
        options: ['Shape', 'Color', 'Size'],
        correctIndex: 1,
      ),
    ],
  ),
  LearningLevel(
    id: 'logic-stage4-1',
    moduleId: 'logic',
    stage: 4,
    levelNumber: 1,
    title: 'Pattern Builder',
    subtitle: 'Complete longer repeating patterns.',
    type: LevelType.matching,
    passingScore: 75,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Clap',
        prompt: 'Clap, tap, clap, tap. Choose clap to start again.',
        displayText: 'C T C T _',
        visualLabel: 'Clap tap repeating action pattern',
        audioCueKey: 'logic_clap',
      ),
      ContentItem(
        title: 'Circle',
        prompt: 'Triangle, circle, triangle. Choose circle next.',
        displayText: '△ O △ _',
        visualLabel: 'Triangle circle triangle circle pattern',
        audioCueKey: 'logic_circle',
      ),
      ContentItem(
        title: 'Short',
        prompt: 'Tall, short, tall. Choose short next.',
        displayText: 'Tall Short Tall _',
        visualLabel: 'Tall short size pattern',
        audioCueKey: 'logic_short',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'logic-builder-q1',
        prompt: 'Clap, tap, clap, tap. What starts the pattern again?',
        options: ['Clap', 'Jump', 'Spin'],
        correctIndex: 0,
        explanation: 'After clap, tap, clap, tap, clap starts it again.',
      ),
      QuizQuestion(
        id: 'logic-builder-q2',
        prompt: 'Tall, short, tall. What comes next?',
        options: ['Tall', 'Short', 'Round'],
        correctIndex: 1,
        explanation: 'The pattern repeats tall, short.',
      ),
    ],
  ),
  LearningLevel(
    id: 'logic-stage4-2',
    moduleId: 'logic',
    stage: 4,
    levelNumber: 2,
    title: 'Puzzle Paths',
    subtitle: 'Follow simple clues to choose the right path.',
    type: LevelType.matching,
    passingScore: 75,
    isBundled: false,
    contentItems: [
      ContentItem(
        title: 'Left',
        prompt: 'The star is on the left path. Choose left.',
        displayText: 'Left',
        visualLabel: 'Star on the left path',
        audioCueKey: 'logic_left',
      ),
      ContentItem(
        title: 'Middle',
        prompt: 'The circle is in the middle path. Choose middle.',
        displayText: 'Middle',
        visualLabel: 'Circle in the middle path',
        audioCueKey: 'logic_middle',
      ),
      ContentItem(
        title: 'Right',
        prompt: 'The square is on the right path. Choose right.',
        displayText: 'Right',
        visualLabel: 'Square on the right path',
        audioCueKey: 'logic_right',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'logic-path-q1',
        prompt: 'If the star is on the left path, which path do you pick?',
        options: ['Middle', 'Right', 'Left'],
        correctIndex: 2,
      ),
    ],
  ),
  LearningLevel(
    id: 'story-stage2-1',
    moduleId: 'story',
    stage: 2,
    levelNumber: 1,
    title: 'First and Then',
    subtitle: 'Tell what happens first and what happens next.',
    type: LevelType.story,
    passingScore: 65,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'First',
        prompt: 'First, the cup is empty. Say first.',
        displayText: 'First',
        visualLabel: 'Empty cup picture',
        audioCueKey: 'story_first',
      ),
      ContentItem(
        title: 'Then',
        prompt: 'Then, the cup is full. Say then.',
        displayText: 'Then',
        visualLabel: 'Full cup picture',
        audioCueKey: 'story_then',
      ),
      ContentItem(
        title: 'Done',
        prompt: 'At the end, the cup is back on the tray.',
        displayText: 'Done',
        visualLabel: 'Cup on tray picture',
        audioCueKey: 'story_done',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'story-first-q1',
        prompt: 'Which word tells the start of a story?',
        options: ['First', 'Then', 'Done'],
        correctIndex: 0,
        explanation: 'First tells what happens at the start.',
      ),
    ],
  ),
  LearningLevel(
    id: 'story-stage3-1',
    moduleId: 'story',
    stage: 3,
    levelNumber: 1,
    title: 'Kite Day',
    subtitle: 'Tell a short story with a beginning, middle, and end.',
    type: LevelType.story,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Beginning',
        prompt: 'Nina holds a red kite. Tell the beginning.',
        displayText: 'Start',
        visualLabel: 'Nina holding a red kite',
        audioCueKey: 'story_kite_start',
      ),
      ContentItem(
        title: 'Middle',
        prompt: 'The kite goes up in the wind. Tell the middle.',
        displayText: 'Up',
        visualLabel: 'Kite flying high',
        audioCueKey: 'story_kite_middle',
      ),
      ContentItem(
        title: 'End',
        prompt: 'Nina rolls up the string. Tell the ending.',
        displayText: 'End',
        visualLabel: 'Kite string rolled up',
        audioCueKey: 'story_kite_end',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'story-kite-q1',
        prompt: 'What does Nina hold at the beginning?',
        options: ['A kite', 'A cup', 'A hat'],
        correctIndex: 0,
        explanation: 'Nina holds a kite at the beginning.',
      ),
      QuizQuestion(
        id: 'story-kite-q2',
        prompt: 'Which part comes last?',
        options: ['Beginning', 'End', 'Middle'],
        correctIndex: 1,
        explanation: 'The end comes last.',
      ),
    ],
  ),
  LearningLevel(
    id: 'story-stage3-2',
    moduleId: 'story',
    stage: 3,
    levelNumber: 2,
    title: 'Rainy Window',
    subtitle: 'Put three picture moments in order.',
    type: LevelType.story,
    passingScore: 70,
    isBundled: false,
    contentItems: [
      ContentItem(
        title: 'Clouds',
        prompt: 'Clouds cover the sky. Tell what might happen next.',
        displayText: 'Clouds',
        visualLabel: 'Cloudy sky picture',
        audioCueKey: 'story_clouds',
      ),
      ContentItem(
        title: 'Rain',
        prompt: 'Rain taps the window. Tell the middle.',
        displayText: 'Rain',
        visualLabel: 'Rain on window picture',
        audioCueKey: 'story_rain',
      ),
      ContentItem(
        title: 'Boots',
        prompt: 'Boots wait by the door. Tell the ending.',
        displayText: 'Boots',
        visualLabel: 'Boots by the door picture',
        audioCueKey: 'story_boots',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'story-rain-q1',
        prompt: 'What happens after clouds cover the sky?',
        options: ['Rain', 'Snack', 'Bedtime'],
        correctIndex: 0,
      ),
    ],
  ),
  LearningLevel(
    id: 'story-stage4-1',
    moduleId: 'story',
    stage: 4,
    levelNumber: 1,
    title: 'Make a Story',
    subtitle: 'Use who, where, and what happened to tell your own story.',
    type: LevelType.story,
    passingScore: 75,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Who',
        prompt: 'Choose who is in your story and say their name.',
        displayText: 'Who',
        visualLabel: 'Character choice picture',
        audioCueKey: 'story_who',
      ),
      ContentItem(
        title: 'Where',
        prompt: 'Choose where the story happens.',
        displayText: 'Where',
        visualLabel: 'Place choice picture',
        audioCueKey: 'story_where',
      ),
      ContentItem(
        title: 'What',
        prompt: 'Tell what happened in one short sentence.',
        displayText: 'What',
        visualLabel: 'Story action picture',
        audioCueKey: 'story_what',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'story-make-q1',
        prompt: 'Which question asks for the person in a story?',
        options: ['Where?', 'Who?', 'What?'],
        correctIndex: 1,
        explanation: 'Who asks for the person in a story.',
      ),
      QuizQuestion(
        id: 'story-make-q2',
        prompt: 'Which question asks for the place?',
        options: ['Where?', 'Who?', 'What?'],
        correctIndex: 0,
        explanation: 'Where asks for the place.',
      ),
    ],
  ),
  LearningLevel(
    id: 'story-stage4-2',
    moduleId: 'story',
    stage: 4,
    levelNumber: 2,
    title: 'Story Sequencer',
    subtitle: 'Practice beginning, middle, and end with new pictures.',
    type: LevelType.story,
    passingScore: 75,
    isBundled: false,
    contentItems: [
      ContentItem(
        title: 'Beginning',
        prompt: 'A box is closed. Tell the beginning.',
        displayText: 'Start',
        visualLabel: 'Closed box picture',
        audioCueKey: 'story_box_start',
      ),
      ContentItem(
        title: 'Middle',
        prompt: 'The box opens. Tell the middle.',
        displayText: 'Open',
        visualLabel: 'Open box picture',
        audioCueKey: 'story_box_middle',
      ),
      ContentItem(
        title: 'End',
        prompt: 'Blocks come out of the box. Tell the end.',
        displayText: 'End',
        visualLabel: 'Blocks from box picture',
        audioCueKey: 'story_box_end',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'story-sequence-q1',
        prompt: 'What comes between beginning and end?',
        options: ['Middle', 'Title', 'Cover'],
        correctIndex: 0,
      ),
    ],
  ),
  LearningLevel(
    id: 'drawing-stage2-1',
    moduleId: 'drawing',
    stage: 2,
    levelNumber: 1,
    title: 'Shape Coloring',
    subtitle: 'Color simple shapes and say their names.',
    type: LevelType.drawing,
    passingScore: 65,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Circle',
        prompt: 'Color the circle with any color you like.',
        displayText: 'Circle',
        visualLabel: 'Circle coloring prompt',
        audioCueKey: 'drawing_circle',
      ),
      ContentItem(
        title: 'Square',
        prompt: 'Color the square and say square.',
        displayText: 'Square',
        visualLabel: 'Square coloring prompt',
        audioCueKey: 'drawing_square',
      ),
      ContentItem(
        title: 'Line',
        prompt: 'Draw a line under your shape.',
        displayText: 'Line',
        visualLabel: 'Line drawing prompt',
        audioCueKey: 'drawing_line',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'drawing-shape-q1',
        prompt: 'Which shape is round?',
        options: ['Circle', 'Square', 'Line'],
        correctIndex: 0,
        explanation: 'A circle is round.',
      ),
    ],
  ),
  LearningLevel(
    id: 'drawing-stage3-1',
    moduleId: 'drawing',
    stage: 3,
    levelNumber: 1,
    title: 'Draw Shapes',
    subtitle: 'Use colors to draw and name familiar shapes.',
    type: LevelType.drawing,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Triangle',
        prompt: 'Draw a triangle with three sides.',
        displayText: 'Triangle',
        visualLabel: 'Triangle drawing prompt',
        audioCueKey: 'drawing_triangle',
      ),
      ContentItem(
        title: 'Rectangle',
        prompt: 'Draw a tall rectangle.',
        displayText: 'Rectangle',
        visualLabel: 'Rectangle drawing prompt',
        audioCueKey: 'drawing_rectangle',
      ),
      ContentItem(
        title: 'Pattern',
        prompt: 'Draw a line, dot, line, dot pattern.',
        displayText: 'Pattern',
        visualLabel: 'Line dot pattern prompt',
        audioCueKey: 'drawing_pattern',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'drawing-shape-q2',
        prompt: 'Which shape has three sides?',
        options: ['Circle', 'Triangle', 'Rectangle'],
        correctIndex: 1,
        explanation: 'A triangle has three sides.',
      ),
      QuizQuestion(
        id: 'drawing-pattern-q1',
        prompt: 'Line, dot, line. What comes next?',
        options: ['Dot', 'Line', 'Circle'],
        correctIndex: 0,
        explanation: 'The pattern repeats line, dot.',
      ),
    ],
  ),
  LearningLevel(
    id: 'drawing-stage3-2',
    moduleId: 'drawing',
    stage: 3,
    levelNumber: 2,
    title: 'Color Patterns',
    subtitle: 'Make repeating color patterns.',
    type: LevelType.drawing,
    passingScore: 70,
    isBundled: false,
    contentItems: [
      ContentItem(
        title: 'Red Blue',
        prompt: 'Draw red, blue, red, blue marks.',
        displayText: 'R B',
        visualLabel: 'Red blue color pattern prompt',
        audioCueKey: 'drawing_red_blue',
      ),
      ContentItem(
        title: 'Yellow Green',
        prompt: 'Draw yellow, green, yellow, green marks.',
        displayText: 'Y G',
        visualLabel: 'Yellow green color pattern prompt',
        audioCueKey: 'drawing_yellow_green',
      ),
      ContentItem(
        title: 'Frame',
        prompt: 'Draw a color frame around your page.',
        displayText: 'Frame',
        visualLabel: 'Color frame prompt',
        audioCueKey: 'drawing_frame',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'drawing-color-pattern-q1',
        prompt: 'Red, blue, red. What color comes next?',
        options: ['Blue', 'Red', 'Green'],
        correctIndex: 0,
      ),
    ],
  ),
  LearningLevel(
    id: 'drawing-stage4-1',
    moduleId: 'drawing',
    stage: 4,
    levelNumber: 1,
    title: 'Picture Prompts',
    subtitle: 'Build a simple picture from three drawing steps.',
    type: LevelType.drawing,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Sky',
        prompt: 'Draw the sky at the top of your page.',
        displayText: 'Sky',
        visualLabel: 'Sky drawing prompt',
        audioCueKey: 'drawing_sky',
      ),
      ContentItem(
        title: 'House',
        prompt: 'Draw a house under the sky.',
        displayText: 'House',
        visualLabel: 'House drawing prompt',
        audioCueKey: 'drawing_house',
      ),
      ContentItem(
        title: 'Path',
        prompt: 'Draw a path from the house to the bottom of the page.',
        displayText: 'Path',
        visualLabel: 'Path drawing prompt',
        audioCueKey: 'drawing_path',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'drawing-picture-q1',
        prompt: 'Where should the sky go?',
        options: ['Top', 'Middle', 'Bottom'],
        correctIndex: 0,
        explanation: 'The sky goes at the top of the page.',
      ),
      QuizQuestion(
        id: 'drawing-picture-q2',
        prompt: 'What can connect the house to the bottom of the page?',
        options: ['Path', 'Cloud', 'Dot'],
        correctIndex: 0,
        explanation: 'A path can connect the house to the bottom.',
      ),
    ],
  ),
  LearningLevel(
    id: 'drawing-stage4-2',
    moduleId: 'drawing',
    stage: 4,
    levelNumber: 2,
    title: 'Color Story',
    subtitle: 'Draw a beginning, middle, and end with colors.',
    type: LevelType.drawing,
    passingScore: 70,
    isBundled: false,
    contentItems: [
      ContentItem(
        title: 'Start',
        prompt: 'Draw one shape to start your picture story.',
        displayText: 'Start',
        visualLabel: 'Picture story start prompt',
        audioCueKey: 'drawing_story_start',
      ),
      ContentItem(
        title: 'Add',
        prompt: 'Add a second shape or color in the middle.',
        displayText: 'Add',
        visualLabel: 'Picture story middle prompt',
        audioCueKey: 'drawing_story_middle',
      ),
      ContentItem(
        title: 'Finish',
        prompt: 'Finish with one final color mark.',
        displayText: 'Finish',
        visualLabel: 'Picture story ending prompt',
        audioCueKey: 'drawing_story_end',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'drawing-story-q1',
        prompt: 'Which part comes first in a picture story?',
        options: ['Start', 'Add', 'Finish'],
        correctIndex: 0,
      ),
    ],
  ),
  // Video module. Each stop is one short film bundled under
  // assets/videos/age{stage}/, so a lesson plays with no connection — the
  // module the age packs deliberately do not carry. Stops are ordered
  // shortest film first, because a level is only unlocked by finishing the
  // one before it and attention grows with age. Every film opens on a drawn
  // card of its subject and then shows the real thing.
  LearningLevel(
    id: 'video-stage2-1',
    moduleId: 'video',
    stage: 2,
    levelNumber: 1,
    title: 'The Butterfly',
    subtitle: 'A butterfly opens its wings on a yellow flower.',
    type: LevelType.video,
    passingScore: 70,
    isBundled: true,
    videoLessons: [
      VideoLesson(
        id: 'video-butterfly',
        title: 'Butterfly',
        description: 'An orange butterfly rests on a flower.',
        durationLabel: '0:12',
        videoUrl: 'assets/videos/age2/butterfly.mp4',
        thumbnailLabel: 'Butterfly on a yellow flower',
      ),
    ],
  ),
  LearningLevel(
    id: 'video-stage2-2',
    moduleId: 'video',
    stage: 2,
    levelNumber: 2,
    title: 'The Ducks',
    subtitle: 'Two ducks swim, then dip under the water.',
    type: LevelType.video,
    passingScore: 70,
    isBundled: true,
    videoLessons: [
      VideoLesson(
        id: 'video-duck',
        title: 'Duck',
        description: 'Two white ducks swim on a pond.',
        durationLabel: '0:16',
        videoUrl: 'assets/videos/age2/duck.mp4',
        thumbnailLabel: 'Two ducks on the water',
      ),
    ],
  ),
  LearningLevel(
    id: 'video-stage2-3',
    moduleId: 'video',
    stage: 2,
    levelNumber: 3,
    title: 'The Tortoise',
    subtitle: 'Slow climbers rest on a rock by the water.',
    type: LevelType.video,
    passingScore: 70,
    isBundled: true,
    videoLessons: [
      VideoLesson(
        id: 'video-tortoise',
        title: 'Tortoise',
        description: 'They climb the rock slowly, one over the other.',
        durationLabel: '0:31',
        videoUrl: 'assets/videos/age2/tortoise.mp4',
        thumbnailLabel: 'Tortoises on a rock',
      ),
    ],
  ),
  LearningLevel(
    id: 'video-stage3-1',
    moduleId: 'video',
    stage: 3,
    levelNumber: 1,
    title: 'The Busy Bee',
    subtitle: 'A bee works its way around a yellow flower.',
    type: LevelType.video,
    passingScore: 70,
    isBundled: true,
    videoLessons: [
      VideoLesson(
        id: 'video-bee',
        title: 'Bee',
        description: 'A bee lands on a dandelion and crawls over it.',
        durationLabel: '0:13',
        videoUrl: 'assets/videos/age3/bee.mp4',
        thumbnailLabel: 'Bee on a dandelion',
      ),
    ],
  ),
  LearningLevel(
    id: 'video-stage3-2',
    moduleId: 'video',
    stage: 3,
    levelNumber: 2,
    title: 'The Spider Web',
    subtitle: 'A spider waits in the middle of its web.',
    type: LevelType.video,
    passingScore: 70,
    isBundled: true,
    videoLessons: [
      VideoLesson(
        id: 'video-spider',
        title: 'Spider',
        description: 'A small spider sits still in a web it spun.',
        durationLabel: '0:25',
        videoUrl: 'assets/videos/age3/spider.mp4',
        thumbnailLabel: 'Spider in its web',
      ),
    ],
  ),
  LearningLevel(
    id: 'video-stage3-3',
    moduleId: 'video',
    stage: 3,
    levelNumber: 3,
    title: 'The Elephants',
    subtitle: 'A herd walks together across the grass.',
    type: LevelType.video,
    passingScore: 70,
    isBundled: true,
    videoLessons: [
      VideoLesson(
        id: 'video-elephant',
        title: 'Elephant',
        description: 'Big and small elephants walk side by side.',
        durationLabel: '0:28',
        videoUrl: 'assets/videos/age3/elephant.mp4',
        thumbnailLabel: 'A herd of elephants',
      ),
    ],
  ),
  LearningLevel(
    id: 'video-stage4-1',
    moduleId: 'video',
    stage: 4,
    levelNumber: 1,
    title: 'The Candle Burns',
    subtitle: 'A flame burns and the candle grows shorter.',
    type: LevelType.video,
    passingScore: 70,
    isBundled: true,
    videoLessons: [
      VideoLesson(
        id: 'video-candle',
        title: 'Candle',
        description: 'The flame stays lit while the wax melts away.',
        durationLabel: '0:22',
        videoUrl: 'assets/videos/age4/candle.mp4',
        thumbnailLabel: 'A burning candle',
      ),
    ],
  ),
  LearningLevel(
    id: 'video-stage4-2',
    moduleId: 'video',
    stage: 4,
    levelNumber: 2,
    title: 'A Seed Grows',
    subtitle: 'A seed sends a root down and a shoot up.',
    type: LevelType.video,
    passingScore: 70,
    isBundled: true,
    videoLessons: [
      VideoLesson(
        id: 'video-plant',
        title: 'Plant',
        description: 'Days of growing, sped up into one short film.',
        durationLabel: '0:25',
        videoUrl: 'assets/videos/age4/plant.mp4',
        thumbnailLabel: 'A seed sprouting in soil',
      ),
    ],
  ),
  LearningLevel(
    id: 'video-stage4-3',
    moduleId: 'video',
    stage: 4,
    levelNumber: 3,
    title: 'Ice Melts',
    subtitle: 'An ice cube turns into a puddle of water.',
    type: LevelType.video,
    passingScore: 70,
    isBundled: true,
    videoLessons: [
      VideoLesson(
        id: 'video-ice',
        title: 'Ice',
        description: 'Watch solid ice slowly become water.',
        durationLabel: '0:29',
        videoUrl: 'assets/videos/age4/ice.mp4',
        thumbnailLabel: 'An ice cube melting',
      ),
    ],
  ),

  // Tracing module. `displayText` holds the exact glyph that is drawn as the
  // dotted guide and graded, so it must be the character itself and nothing
  // more. Quizzes check that the child recognises what they just traced; the
  // level score averages the tracing accuracy with the quiz result.
  LearningLevel(
    id: 'tracing-stage2-1',
    portionLabel: 'A – C',
    moduleId: 'tracing',
    stage: 2,
    levelNumber: 1,
    title: 'Trace A B C',
    subtitle: 'Follow the dots to write your first capital letters.',
    type: LevelType.tracing,
    passingScore: 50,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Letter A',
        prompt: 'Trace the letter A along the dots.',
        displayText: 'A',
        visualLabel: 'Dotted capital letter A',
        audioCueKey: 'trace_letter_a',
      ),
      ContentItem(
        title: 'Letter B',
        prompt: 'Trace the letter B along the dots.',
        displayText: 'B',
        visualLabel: 'Dotted capital letter B',
        audioCueKey: 'trace_letter_b',
      ),
      ContentItem(
        title: 'Letter C',
        prompt: 'Trace the letter C along the dots.',
        displayText: 'C',
        visualLabel: 'Dotted capital letter C',
        audioCueKey: 'trace_letter_c',
      ),
    ],
  ),
  LearningLevel(
    id: 'tracing-stage2-2',
    portionLabel: '1 – 3',
    moduleId: 'tracing',
    stage: 2,
    levelNumber: 2,
    title: 'Trace 1 2 3',
    subtitle: 'Write your first three numbers on the dots.',
    type: LevelType.tracing,
    passingScore: 50,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Number 1',
        prompt: 'Trace the number one, straight down.',
        displayText: '1',
        visualLabel: 'Dotted number 1',
        audioCueKey: 'trace_number_1',
      ),
      ContentItem(
        title: 'Number 2',
        prompt: 'Trace the number two, around and across.',
        displayText: '2',
        visualLabel: 'Dotted number 2',
        audioCueKey: 'trace_number_2',
      ),
      ContentItem(
        title: 'Number 3',
        prompt: 'Trace the number three, two little curves.',
        displayText: '3',
        visualLabel: 'Dotted number 3',
        audioCueKey: 'trace_number_3',
      ),
    ],
  ),
  LearningLevel(
    id: 'tracing-stage3-1',
    portionLabel: 'a – c',
    moduleId: 'tracing',
    stage: 3,
    levelNumber: 1,
    title: 'Trace a b c',
    subtitle: 'Small letters, one dotted line at a time.',
    type: LevelType.tracing,
    passingScore: 60,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Letter a',
        prompt: 'Trace the small letter a.',
        displayText: 'a',
        visualLabel: 'Dotted small letter a',
        audioCueKey: 'trace_letter_a_small',
      ),
      ContentItem(
        title: 'Letter b',
        prompt: 'Trace the small letter b.',
        displayText: 'b',
        visualLabel: 'Dotted small letter b',
        audioCueKey: 'trace_letter_b_small',
      ),
      ContentItem(
        title: 'Letter c',
        prompt: 'Trace the small letter c.',
        displayText: 'c',
        visualLabel: 'Dotted small letter c',
        audioCueKey: 'trace_letter_c_small',
      ),
      ContentItem(
        title: 'Letter d',
        prompt: 'Trace the small letter d.',
        displayText: 'd',
        visualLabel: 'Dotted small letter d',
        audioCueKey: 'trace_letter_d_small',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'tracing-abc-q1',
        prompt: 'Which small letter did you just trace first?',
        options: ['a', 'z', 'm'],
        correctIndex: 0,
        explanation: 'The first card was the small letter a.',
      ),
      QuizQuestion(
        id: 'tracing-abc-q2',
        prompt: 'Which letter has a tall line and a round tummy?',
        options: ['b', 'c', 'a'],
        correctIndex: 0,
        explanation: 'The letter b has a tall line and a round tummy.',
      ),
    ],
  ),
  LearningLevel(
    id: 'tracing-stage3-2',
    portionLabel: '4 – 6',
    moduleId: 'tracing',
    stage: 3,
    levelNumber: 2,
    title: 'Trace 4 5 6',
    subtitle: 'Bigger numbers, same dotted lines.',
    type: LevelType.tracing,
    passingScore: 60,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Number 4',
        prompt: 'Trace the number four.',
        displayText: '4',
        visualLabel: 'Dotted number 4',
        audioCueKey: 'trace_number_4',
      ),
      ContentItem(
        title: 'Number 5',
        prompt: 'Trace the number five.',
        displayText: '5',
        visualLabel: 'Dotted number 5',
        audioCueKey: 'trace_number_5',
      ),
      ContentItem(
        title: 'Number 6',
        prompt: 'Trace the number six.',
        displayText: '6',
        visualLabel: 'Dotted number 6',
        audioCueKey: 'trace_number_6',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'tracing-456-q1',
        prompt: 'Which number comes after 4?',
        options: ['5', '3', '9'],
        correctIndex: 0,
        explanation: 'Counting up from 4 gives 5.',
      ),
    ],
  ),
  LearningLevel(
    id: 'tracing-stage3-3',
    moduleId: 'tracing',
    stage: 3,
    levelNumber: 3,
    title: 'اردو حروف لکھیں',
    subtitle: 'نقطوں پر انگلی چلا کر اردو حروف بنائیں۔',
    type: LevelType.tracing,
    passingScore: 60,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'الف',
        prompt: 'نقطوں پر الف بنائیں۔',
        displayText: 'ا',
        visualLabel: 'نقطوں والا الف',
        audioCueKey: 'trace_urdu_alif',
      ),
      ContentItem(
        title: 'بے',
        prompt: 'نقطوں پر بے بنائیں۔',
        displayText: 'ب',
        visualLabel: 'نقطوں والی بے',
        audioCueKey: 'trace_urdu_bay',
      ),
      ContentItem(
        title: 'پے',
        prompt: 'نقطوں پر پے بنائیں۔',
        displayText: 'پ',
        visualLabel: 'نقطوں والی پے',
        audioCueKey: 'trace_urdu_pay',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'tracing-urdu-q1',
        prompt: 'اردو کا پہلا حرف کون سا ہے؟',
        options: ['ا', 'ب', 'پ'],
        correctIndex: 0,
        explanation: 'اردو کا پہلا حرف الف ہے۔',
      ),
    ],
  ),
  LearningLevel(
    id: 'tracing-stage4-1',
    moduleId: 'tracing',
    stage: 4,
    levelNumber: 1,
    title: 'Trace Name Letters',
    subtitle: 'Neat capitals that show up in lots of names.',
    type: LevelType.tracing,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Letter M',
        prompt: 'Trace the letter M without lifting your finger.',
        displayText: 'M',
        visualLabel: 'Dotted capital letter M',
        audioCueKey: 'trace_letter_m',
      ),
      ContentItem(
        title: 'Letter S',
        prompt: 'Trace the curvy letter S.',
        displayText: 'S',
        visualLabel: 'Dotted capital letter S',
        audioCueKey: 'trace_letter_s',
      ),
      ContentItem(
        title: 'Letter T',
        prompt: 'Trace the letter T, down then across.',
        displayText: 'T',
        visualLabel: 'Dotted capital letter T',
        audioCueKey: 'trace_letter_t',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'tracing-names-q1',
        prompt: 'Which letter is made of one line down and one across?',
        options: ['T', 'S', 'M'],
        correctIndex: 0,
        explanation: 'T is a line down with a line across the top.',
      ),
      QuizQuestion(
        id: 'tracing-names-q2',
        prompt: 'Which letter is the curvy one?',
        options: ['S', 'T', 'M'],
        correctIndex: 0,
        explanation: 'S curves one way and then the other.',
      ),
    ],
  ),
  LearningLevel(
    id: 'tracing-stage4-2',
    portionLabel: '7 – 9',
    moduleId: 'tracing',
    stage: 4,
    levelNumber: 2,
    title: 'Trace 7 8 9',
    subtitle: 'The last single numbers, traced slowly.',
    type: LevelType.tracing,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Number 7',
        prompt: 'Trace the number seven, across then down.',
        displayText: '7',
        visualLabel: 'Dotted number 7',
        audioCueKey: 'trace_number_7',
      ),
      ContentItem(
        title: 'Number 8',
        prompt: 'Trace the number eight, two circles.',
        displayText: '8',
        visualLabel: 'Dotted number 8',
        audioCueKey: 'trace_number_8',
      ),
      ContentItem(
        title: 'Number 9',
        prompt: 'Trace the number nine, a circle and a line.',
        displayText: '9',
        visualLabel: 'Dotted number 9',
        audioCueKey: 'trace_number_9',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'tracing-789-q1',
        prompt: 'Which number is made of two circles?',
        options: ['8', '7', '9'],
        correctIndex: 0,
        explanation: 'The number 8 is two circles stacked up.',
      ),
    ],
  ),
  LearningLevel(
    id: 'tracing-stage4-3',
    moduleId: 'tracing',
    stage: 4,
    levelNumber: 3,
    title: 'صاف اردو لکھائی',
    subtitle: 'حروف کو نقطوں پر صاف اور آہستہ لکھیں۔',
    type: LevelType.tracing,
    passingScore: 70,
    isBundled: false,
    contentItems: [
      ContentItem(
        title: 'سین',
        prompt: 'نقطوں پر سین بنائیں۔',
        displayText: 'س',
        visualLabel: 'نقطوں والی سین',
        audioCueKey: 'trace_urdu_seen',
      ),
      ContentItem(
        title: 'میم',
        prompt: 'نقطوں پر میم بنائیں۔',
        displayText: 'م',
        visualLabel: 'نقطوں والی میم',
        audioCueKey: 'trace_urdu_meem',
      ),
      ContentItem(
        title: 'نون',
        prompt: 'نقطوں پر نون بنائیں۔',
        displayText: 'ن',
        visualLabel: 'نقطوں والی نون',
        audioCueKey: 'trace_urdu_noon',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'tracing-urdu-q2',
        prompt: 'کون سا حرف نقطے والا ہے؟',
        options: ['ن', 'س', 'م'],
        correctIndex: 0,
        explanation: 'نون کے اوپر ایک نقطہ ہوتا ہے۔',
      ),
    ],
  ),
];

// --- English alphabet ladder ------------------------------------------------

/// One rung of a module's sequence: the glyph a child learns and the word that
/// anchors it. Every word starts with its own glyph, so the same table can
/// drive both the cards and the quiz.
class _AlphabetEntry {
  const _AlphabetEntry(this.glyph, this.word, this.audioCueKey);

  final String glyph;
  final String word;
  final String audioCueKey;
}

const _englishAlphabet = <_AlphabetEntry>[
  _AlphabetEntry('A', 'apple', 'english_letter_a'),
  _AlphabetEntry('B', 'ball', 'english_letter_b'),
  _AlphabetEntry('C', 'cat', 'english_letter_c'),
  _AlphabetEntry('D', 'dog', 'english_letter_d'),
  _AlphabetEntry('E', 'egg', 'english_letter_e'),
  _AlphabetEntry('F', 'fish', 'english_letter_f'),
  _AlphabetEntry('G', 'goat', 'english_letter_g'),
  _AlphabetEntry('H', 'hat', 'english_letter_h'),
  _AlphabetEntry('I', 'igloo', 'english_letter_i'),
  _AlphabetEntry('J', 'jug', 'english_letter_j'),
  _AlphabetEntry('K', 'kite', 'english_letter_k'),
  _AlphabetEntry('L', 'leaf', 'english_letter_l'),
  _AlphabetEntry('M', 'moon', 'english_letter_m'),
  _AlphabetEntry('N', 'nest', 'english_letter_n'),
  _AlphabetEntry('O', 'orange', 'english_letter_o'),
  _AlphabetEntry('P', 'pen', 'english_letter_p'),
  _AlphabetEntry('Q', 'queen', 'english_letter_q'),
  _AlphabetEntry('R', 'rain', 'english_letter_r'),
  _AlphabetEntry('S', 'sun', 'english_letter_s'),
  _AlphabetEntry('T', 'tree', 'english_letter_t'),
  _AlphabetEntry('U', 'umbrella', 'english_letter_u'),
  _AlphabetEntry('V', 'van', 'english_letter_v'),
  _AlphabetEntry('W', 'water', 'english_letter_w'),
  // Not "box": the quiz asks which letter a word starts with, so every word
  // here has to actually begin with its own glyph.
  _AlphabetEntry('X', 'xylophone', 'english_letter_x'),
  _AlphabetEntry('Y', 'yarn', 'english_letter_y'),
  _AlphabetEntry('Z', 'zebra', 'english_letter_z'),
];

/// Where each level starts and stops in [_englishAlphabet]. Four portions cover
/// the whole alphabet; the last one takes eight letters so nothing is left over.
const _englishPortionBounds = <List<int>>[
  [0, 6], // A – F
  [6, 12], // G – L
  [12, 18], // M – R
  [18, 26], // S – Z
];

List<LearningLevel> _englishAlphabetLevels() {
  final levels = <LearningLevel>[];

  for (var stage = AgeStageHelper.minStage; stage <= 4; stage++) {
    for (var index = 0; index < _englishPortionBounds.length; index++) {
      final bounds = _englishPortionBounds[index];
      final entries = _englishAlphabet.sublist(bounds.first, bounds.last);
      final portion = '${entries.first.glyph} – ${entries.last.glyph}';
      final levelNumber = index + 1;

      levels.add(
        LearningLevel(
          id: 'english-stage$stage-$levelNumber',
          moduleId: 'english',
          stage: stage,
          levelNumber: levelNumber,
          title: 'Letters $portion',
          subtitle: _englishSubtitle(stage),
          // Older children match letters to words instead of only meeting them.
          type: stage >= 4 ? LevelType.matching : LevelType.flashcards,
          passingScore: 55 + stage * 5,
          isBundled: true,
          portionLabel: portion,
          contentItems: [
            for (final entry in entries)
              ContentItem(
                title: entry.glyph,
                prompt: _englishPrompt(stage, entry),
                displayText: entry.glyph,
                visualLabel: 'Letter ${entry.glyph} with a picture of '
                    '${entry.word}',
                audioCueKey: entry.audioCueKey,
              ),
          ],
          // Quizzes start at stage 3, matching AgeStageHelper.shouldShowQuiz.
          quizQuestions: stage >= 3
              ? _englishQuizQuestions(stage, levelNumber, entries)
              : const [],
        ),
      );
    }
  }

  return levels;
}

String _englishSubtitle(int stage) {
  return switch (stage) {
    2 => 'Hear each letter and copy the sound.',
    3 => 'Say each letter, then the word it starts.',
    _ => 'Match every letter to a word that starts with it.',
  };
}

String _englishPrompt(int stage, _AlphabetEntry entry) {
  final glyph = entry.glyph;
  return switch (stage) {
    2 => '$glyph is for ${entry.word}. Say $glyph.',
    3 => '$glyph is for ${entry.word}. Say the letter, then say the word.',
    _ => '$glyph is for ${entry.word}. Can you think of another word that '
        'starts with $glyph?',
  };
}

/// Two questions per level, drawn from opposite ends of the portion so the
/// quiz covers more than the letters a child saw most recently.
List<QuizQuestion> _englishQuizQuestions(
  int stage,
  int levelNumber,
  List<_AlphabetEntry> entries,
) {
  final asked = <_AlphabetEntry>[entries.first, entries.last];

  return [
    for (var i = 0; i < asked.length; i++)
      _englishQuestion(
        id: 'english-stage$stage-$levelNumber-q${i + 1}',
        answer: asked[i],
        entries: entries,
        // Move the answer around so it is never always in the same slot.
        answerSlot: i % 3,
      ),
  ];
}

QuizQuestion _englishQuestion({
  required String id,
  required _AlphabetEntry answer,
  required List<_AlphabetEntry> entries,
  required int answerSlot,
}) {
  final options = entries
      .where((entry) => entry.glyph != answer.glyph)
      .take(2)
      .map((entry) => entry.glyph)
      .toList()
    ..insert(answerSlot, answer.glyph);

  return QuizQuestion(
    id: id,
    prompt: 'Which letter does ${answer.word} start with?',
    options: options,
    correctIndex: answerSlot,
  );
}
