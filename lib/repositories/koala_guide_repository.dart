import '../data/koala_guide_content.dart';
import '../models/koala_guide_message.dart';

abstract class KoalaGuideRepository {
  Future<KoalaGuideMessage> getMessage(KoalaGuideRequest request);
}

class SeededKoalaGuideRepository implements KoalaGuideRepository {
  SeededKoalaGuideRepository({
    List<KoalaGuideMessage> seedMessages = seedKoalaGuideMessages,
  }) : _seedMessages = List.unmodifiable(seedMessages);

  final List<KoalaGuideMessage> _seedMessages;
  List<KoalaGuideMessage> _syncedMessages = const [];

  List<KoalaGuideMessage> get seedMessages => _seedMessages;
  List<KoalaGuideMessage> get syncedMessages =>
      List.unmodifiable(_syncedMessages);

  void replaceSyncedMessages(List<KoalaGuideMessage> messages) {
    _syncedMessages = List.unmodifiable(messages);
  }

  @override
  Future<KoalaGuideMessage> getMessage(KoalaGuideRequest request) async {
    final matches = [..._syncedMessages, ..._seedMessages].where((message) {
      return message.matches(request);
    }).toList()
      ..sort((left, right) {
        final byScore = right
            .specificityFor(request)
            .compareTo(left.specificityFor(request));
        if (byScore != 0) return byScore;
        return left.id.compareTo(right.id);
      });

    if (matches.isNotEmpty) {
      return matches.first;
    }

    return KoalaGuideMessage(
      id: 'fallback-${request.trigger.name}-${request.audience.name}',
      trigger: request.trigger,
      audience: request.audience,
      message: request.fallbackMessage ?? 'Let us try this one step at a time.',
      parentTip: request.fallbackParentTip,
      mood: request.audience == KoalaGuideAudience.parent
          ? KoalaGuideMood.parent
          : KoalaGuideMood.encouraging,
    );
  }
}
