import '../models/onboarding.dart';

/// Parent guide and readiness content, mirrored in English and Urdu.
///
/// The two versions are kept in lockstep on purpose: matching `id`s and
/// matching `correctIndex`/option order mean a parent can switch language
/// mid-flow without losing answers or changing which answer is right.

const manualPages = <ManualPageContent>[
  ManualPageContent(
    title: 'Sit Together',
    body: 'Little Learners works best when a parent stays nearby, names the '
        'objects aloud, and celebrates small attempts.',
    iconName: 'family',
  ),
  ManualPageContent(
    title: 'Short Sessions',
    body: 'For ages 2 to 4, keep learning playful and brief. A few calm '
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
  ManualPageContent(
    title: 'You Mark The Drawing',
    body: 'Drawing and tracing are not scored by the app. When the child says '
        'they are done, solve the parent check and give the page a mark '
        'yourself.',
    iconName: 'marking',
  ),
];

const manualPagesUrdu = <ManualPageContent>[
  ManualPageContent(
    title: 'ساتھ بیٹھیں',
    body: 'لٹل لرنرز اُس وقت بہترین کام کرتا ہے جب والدین پاس بیٹھیں، چیزوں کے '
        'نام بلند آواز میں بولیں، اور بچے کی ہر چھوٹی کوشش کو سراہیں۔',
    iconName: 'family',
  ),
  ManualPageContent(
    title: 'مختصر نشستیں',
    body: 'ایک سے چار سال کے بچوں کے لیے سیکھنے کو کھیل جیسا اور مختصر رکھیں۔ '
        'چند پُرسکون منٹ لمبی زبردستی کی نشست سے زیادہ مفید ہیں۔',
    iconName: 'timer',
  ),
  ManualPageContent(
    title: 'رہنمائی کریں، جلدی نہ کریں',
    body: 'بچے کو ٹیپ کرنے، سننے، دہرانے اور دوبارہ کوشش کرنے دیں۔ غلطیاں '
        'سیکھنے کے عمل کا حصہ ہیں۔',
    iconName: 'heart',
  ),
  ManualPageContent(
    title: 'پیرنٹ لاک استعمال کریں',
    body: 'والدین کے حصے ایک آسان سوال کے پیچھے محفوظ رہتے ہیں تاکہ بچہ صرف '
        'سیکھنے کی محفوظ جگہوں میں رہے۔',
    iconName: 'lock',
  ),
  ManualPageContent(
    title: 'ڈرائنگ کے نمبر آپ دیں',
    body: 'ڈرائنگ اور تحریر کو ایپ خود نمبر نہیں دیتی۔ جب بچہ کہے کہ کام مکمل '
        'ہو گیا، تو پیرنٹ چیک حل کریں اور صفحے کو خود نمبر دیں۔',
    iconName: 'marking',
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
    prompt: 'What is a healthy session style for ages 2 to 4?',
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

const readinessQuestionsUrdu = <ReadinessQuestion>[
  ReadinessQuestion(
    id: 'rq-1',
    prompt: 'چھوٹے بچے کو ایپ کیسے استعمال کرنی چاہیے؟',
    options: [
      'والدین کے ساتھ بیٹھ کر',
      'لمبے وقت تک اکیلے',
      'صرف جب بچہ پریشان ہو',
    ],
    correctIndex: 0,
    tip: 'پاس بیٹھیں اور سرگرمی کو مل کر کھیلنے میں بدل دیں۔',
  ),
  ReadinessQuestion(
    id: 'rq-2',
    prompt: 'ایک سے چار سال کے بچوں کے لیے اچھی نشست کیسی ہوتی ہے؟',
    options: [
      'مختصر اور کھیل بھری',
      'جتنی لمبی ہو سکے',
      'صرف سوالنامے',
    ],
    correctIndex: 0,
    tip: 'مختصر نشستیں توجہ بڑھاتی ہیں اور جھنجھلاہٹ کم کرتی ہیں۔',
  ),
  ReadinessQuestion(
    id: 'rq-3',
    prompt: 'جب بچہ غلط جواب دے تو والدین کو کیا کرنا چاہیے؟',
    options: [
      'دوبارہ کوشش کی حوصلہ افزائی کریں',
      'ایپ ہمیشہ کے لیے بند کر دیں',
      'فوراً ڈانٹ دیں',
    ],
    correctIndex: 0,
    tip: 'نرمی سے دوبارہ کوشش کرانا بچوں کا تجسس برقرار رکھتا ہے۔',
  ),
  ReadinessQuestion(
    id: 'rq-4',
    prompt: 'پیرنٹ لاک کیوں رکھا گیا ہے؟',
    options: [
      'والدین کے حصوں کی حفاظت کے لیے',
      'تمام اسباق چھپانے کے لیے',
      'ویڈیوز لمبی کرنے کے لیے',
    ],
    correctIndex: 0,
    tip: 'لاک ترتیبات اور رپورٹس کو بچے کے راستے سے الگ رکھتا ہے۔',
  ),
  ReadinessQuestion(
    id: 'rq-5',
    prompt: 'والدین کو بچے کی پیش رفت کب دیکھنی چاہیے؟',
    options: [
      'پُرسکون نشست مکمل ہونے کے بعد',
      'ہر ٹیپ کے دوران',
      'صرف جب بچہ ناکام ہو',
    ],
    correctIndex: 0,
    tip: 'پیش رفت کو دباؤ نہیں بلکہ نرم جائزہ سمجھیں۔',
  ),
];

List<ManualPageContent> manualPagesFor(OnboardingLanguage language) {
  return switch (language) {
    OnboardingLanguage.english => manualPages,
    OnboardingLanguage.urdu => manualPagesUrdu,
  };
}

List<ReadinessQuestion> readinessQuestionsFor(OnboardingLanguage language) {
  return switch (language) {
    OnboardingLanguage.english => readinessQuestions,
    OnboardingLanguage.urdu => readinessQuestionsUrdu,
  };
}
