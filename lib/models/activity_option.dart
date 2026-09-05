/// One tappable choice inside an activity.
///
/// Every component in the age packs — two-choice, identify, shadow match,
/// odd-one-out, the story choice point — offers the child a row of things to
/// tap and marks exactly one of them right. Sharing a single option type keeps
/// the widgets interchangeable and means a new component gets scoring and
/// feedback for free.
///
/// An option carries a [label], an [image], or both: the English letter rounds
/// are text, the picture rounds are images, and the Urdu letter-shape rounds
/// are images of glyphs. Widgets render whichever is present.
class ActivityOption {
  const ActivityOption({
    this.label,
    this.image,
    this.audio,
    this.isCorrect = false,
    this.scale = 1,
    this.count = 0,
  });

  factory ActivityOption.fromJson(Map<String, dynamic> json) {
    return ActivityOption(
      label: json['label'] as String?,
      image: json['image'] as String?,
      audio: json['audio'] as String?,
      isCorrect: json['correct'] as bool? ?? false,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Text to show, e.g. `A` or `ا`. Null when the option is a picture.
  final String? label;

  /// Asset path of the picture to show. Null when the option is text.
  final String? image;

  /// Played when the child taps this option, e.g. the letter's own sound.
  final String? audio;

  final bool isCorrect;

  /// How large to draw this option relative to its siblings.
  ///
  /// Exists for the big-versus-small round, where the pack points both choices
  /// at one picture and asks the app to draw it at two sizes — so a "big dog"
  /// and a "small dog" need no separate artwork. Everywhere else this is 1 and
  /// changes nothing.
  final double scale;

  /// How many copies of [image] to draw, for a "which plate has more" round.
  /// Zero means the ordinary single picture.
  final int count;

  /// Asset paths this option needs, for the missing-asset audit.
  List<String> get referencedAssets =>
      [image, audio].whereType<String>().toList();

  static List<ActivityOption> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ActivityOption.fromJson)
        .toList();
  }
}
