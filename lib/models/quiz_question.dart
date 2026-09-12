class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.visualLabel,
    this.explanation,
    this.imageUrl,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? visualLabel;
  final String? explanation;

  /// A picture shown above the answers. See [ContentItem.imageUrl].
  final String? imageUrl;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  bool isCorrect(int answerIndex) => answerIndex == correctIndex;
}
