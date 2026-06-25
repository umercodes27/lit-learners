import '../models/onboarding.dart';

const manualPages = <ManualPageContent>[
  ManualPageContent(
    title: 'Sit Together',
    body: 'Little Learners works best when a parent stays nearby, names the '
        'objects aloud, and celebrates small attempts.',
    iconName: 'family',
  ),
  ManualPageContent(
    title: 'Short Sessions',
    body: 'For ages 1 to 4, keep learning playful and brief. A few calm '
        'minutes are more useful than a long forced session.',
    iconName: 'timer',
  ),
  ManualPageContent(
    title: 'Guide, Do Not Rush',
    body: 'Let the child tap, listen, repeat, and try again. Mistakes are part '
        'of the learning loop.',
    iconName: 'heart',
  ),
  ManualPageContent(
    title: 'Use The Lock',
    body: 'Parent areas stay behind a simple challenge so the child remains in '
        'safe learning spaces.',
    iconName: 'lock',
  ),
];

const readinessQuestions = <ReadinessQuestion>[
  ReadinessQuestion(
    id: 'rq-1',
    prompt: 'How should a toddler use the app?',
    options: [
      'With a parent nearby',
      'Alone for a long time',
      'Only when upset',
    ],
    correctIndex: 0,
    tip: 'Stay close and turn the activity into shared play.',
  ),
  ReadinessQuestion(
    id: 'rq-2',
    prompt: 'What is a healthy session style for ages 1 to 4?',
    options: [
      'Short and playful',
      'As long as possible',
      'Only quizzes',
    ],
    correctIndex: 0,
    tip: 'Short sessions help attention and reduce frustration.',
  ),
  ReadinessQuestion(
    id: 'rq-3',
    prompt: 'What should parents do when a child answers incorrectly?',
    options: [
      'Encourage another try',
      'Stop the app forever',
      'Scold immediately',
    ],
    correctIndex: 0,
    tip: 'Gentle retry loops help children stay curious.',
  ),
  ReadinessQuestion(
    id: 'rq-4',
    prompt: 'Why is there a parental lock?',
    options: [
      'To protect parent-only areas',
      'To hide all lessons',
      'To make videos longer',
    ],
    correctIndex: 0,
    tip: 'The lock keeps settings and reports out of the child flow.',
  ),
  ReadinessQuestion(
    id: 'rq-5',
    prompt: 'When should parents check progress?',
    options: [
      'After calm learning sessions',
      'During every tap',
      'Only if the child fails',
    ],
    correctIndex: 0,
    tip: 'Progress is most useful as a gentle review, not pressure.',
  ),
];
