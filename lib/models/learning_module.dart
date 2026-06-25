enum ModuleCategory {
  english,
  math,
  urdu,
  logic,
  story,
  drawing,
  video,
}

class LearningModule {
  const LearningModule({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.minStage,
    required this.maxStage,
    required this.order,
  });

  final String id;
  final String title;
  final String description;
  final ModuleCategory category;
  final int minStage;
  final int maxStage;
  final int order;

  bool supportsStage(int stage) => stage >= minStage && stage <= maxStage;
}
