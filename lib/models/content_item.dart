class ContentItem {
  const ContentItem({
    required this.title,
    required this.prompt,
    required this.displayText,
    required this.visualLabel,
    this.audioCueKey,
  });

  final String title;
  final String prompt;
  final String displayText;
  final String visualLabel;
  final String? audioCueKey;
}
