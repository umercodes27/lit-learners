class ContentItem {
  const ContentItem({
    required this.title,
    required this.prompt,
    required this.displayText,
    required this.visualLabel,
    this.audioCueKey,
    this.imageUrl,
  });

  final String title;
  final String prompt;
  final String displayText;
  final String visualLabel;
  final String? audioCueKey;

  /// A picture an admin attached, as a full https address.
  ///
  /// Optional and additive: [visualLabel] still describes the card, and is
  /// what shows when there is no picture or it will not load. Never produced
  /// by the AI generator — an invented address is a broken image.
  final String? imageUrl;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;
}
