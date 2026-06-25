class LocalDbSchema {
  const LocalDbSchema._();

  static const databaseName = 'little_learners.db';
  static const version = 4;

  static const childProfiles = 'child_profiles';
  static const syncOutbox = 'sync_outbox';
  static const modules = 'modules';
  static const levels = 'levels';
  static const contentItems = 'content_items';
  static const quizQuestions = 'quiz_questions';
  static const videoLessons = 'video_lessons';
  static const levelProgress = 'level_progress';

  static const createChildProfilesTable = '''
CREATE TABLE $childProfiles (
  childId TEXT PRIMARY KEY,
  parentId TEXT NOT NULL,
  name TEXT NOT NULL,
  age INTEGER NOT NULL,
  avatar TEXT NOT NULL,
  leaderboardOptIn INTEGER NOT NULL,
  displayPreference TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  isSynced INTEGER NOT NULL DEFAULT 0
)
''';

  static const createSyncOutboxTable = '''
CREATE TABLE $syncOutbox (
  id TEXT PRIMARY KEY,
  entityType TEXT NOT NULL,
  entityId TEXT NOT NULL,
  operation TEXT NOT NULL,
  payloadJson TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  attemptCount INTEGER NOT NULL DEFAULT 0,
  lastError TEXT
)
''';

  static const createModulesTable = '''
CREATE TABLE $modules (
  moduleId TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  minStage INTEGER NOT NULL,
  maxStage INTEGER NOT NULL,
  sortOrder INTEGER NOT NULL
)
''';

  static const createLevelsTable = '''
CREATE TABLE $levels (
  levelId TEXT PRIMARY KEY,
  moduleId TEXT NOT NULL,
  stage INTEGER NOT NULL,
  levelNumber INTEGER NOT NULL,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL,
  levelType TEXT NOT NULL,
  passingScore INTEGER NOT NULL,
  isBundled INTEGER NOT NULL,
  isDownloaded INTEGER NOT NULL DEFAULT 0
)
''';

  static const createContentItemsTable = '''
CREATE TABLE $contentItems (
  id TEXT PRIMARY KEY,
  levelId TEXT NOT NULL,
  sortOrder INTEGER NOT NULL,
  title TEXT NOT NULL,
  prompt TEXT NOT NULL,
  displayText TEXT NOT NULL,
  visualLabel TEXT NOT NULL,
  audioCueKey TEXT
)
''';

  static const createQuizQuestionsTable = '''
CREATE TABLE $quizQuestions (
  questionId TEXT PRIMARY KEY,
  levelId TEXT NOT NULL,
  sortOrder INTEGER NOT NULL,
  prompt TEXT NOT NULL,
  optionsJson TEXT NOT NULL,
  correctIndex INTEGER NOT NULL,
  visualLabel TEXT,
  explanation TEXT
)
''';

  static const createVideoLessonsTable = '''
CREATE TABLE $videoLessons (
  videoLessonId TEXT PRIMARY KEY,
  levelId TEXT NOT NULL,
  sortOrder INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  durationLabel TEXT NOT NULL,
  videoUrl TEXT NOT NULL,
  thumbnailLabel TEXT NOT NULL
)
''';

  static const createLevelProgressTable = '''
CREATE TABLE $levelProgress (
  childId TEXT NOT NULL,
  moduleId TEXT NOT NULL,
  levelId TEXT NOT NULL,
  completed INTEGER NOT NULL,
  score INTEGER,
  starsEarned INTEGER NOT NULL,
  rewardEarned INTEGER NOT NULL DEFAULT 0,
  rewardEarnedAt TEXT,
  watchedLessonIdsJson TEXT NOT NULL,
  lastWatchedAt TEXT,
  updatedAt TEXT NOT NULL,
  isSynced INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (childId, levelId)
)
''';

  static const indexes = [
    'CREATE INDEX idx_child_profiles_parentId ON $childProfiles(parentId)',
    'CREATE INDEX idx_child_profiles_isSynced ON $childProfiles(isSynced)',
    'CREATE INDEX idx_sync_outbox_createdAt ON $syncOutbox(createdAt)',
    'CREATE INDEX idx_sync_outbox_entity ON $syncOutbox(entityType, entityId)',
    'CREATE INDEX idx_levels_module_stage ON $levels(moduleId, stage)',
    'CREATE INDEX idx_content_items_level ON $contentItems(levelId)',
    'CREATE INDEX idx_quiz_questions_level ON $quizQuestions(levelId)',
    'CREATE INDEX idx_video_lessons_level ON $videoLessons(levelId)',
    'CREATE INDEX idx_level_progress_child ON $levelProgress(childId)',
    'CREATE INDEX idx_level_progress_isSynced ON $levelProgress(isSynced)',
  ];

  static const createStatements = [
    createChildProfilesTable,
    createSyncOutboxTable,
    createModulesTable,
    createLevelsTable,
    createContentItemsTable,
    createQuizQuestionsTable,
    createVideoLessonsTable,
    createLevelProgressTable,
    ...indexes,
  ];

  static const version2Statements = [
    createSyncOutboxTable,
    'CREATE INDEX idx_sync_outbox_createdAt ON $syncOutbox(createdAt)',
    'CREATE INDEX idx_sync_outbox_entity ON $syncOutbox(entityType, entityId)',
  ];

  static const version3Statements = [
    createModulesTable,
    createLevelsTable,
    createContentItemsTable,
    createQuizQuestionsTable,
    createVideoLessonsTable,
    'CREATE INDEX idx_levels_module_stage ON $levels(moduleId, stage)',
    'CREATE INDEX idx_content_items_level ON $contentItems(levelId)',
    'CREATE INDEX idx_quiz_questions_level ON $quizQuestions(levelId)',
    'CREATE INDEX idx_video_lessons_level ON $videoLessons(levelId)',
  ];

  static const version4Statements = [
    createLevelProgressTable,
    'CREATE INDEX idx_level_progress_child ON $levelProgress(childId)',
    'CREATE INDEX idx_level_progress_isSynced ON $levelProgress(isSynced)',
  ];
}
