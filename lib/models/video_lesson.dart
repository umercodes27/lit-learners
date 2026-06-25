class VideoLesson {
  const VideoLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.durationLabel,
    required this.videoUrl,
    required this.thumbnailLabel,
  });

  final String id;
  final String title;
  final String description;
  final String durationLabel;
  final String videoUrl;
  final String thumbnailLabel;
}
