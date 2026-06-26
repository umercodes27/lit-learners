import '../../models/koala_guide_message.dart';

abstract class KoalaGuideRemoteDataSource {
  Future<List<KoalaGuideMessage>> getPublishedMessages();
}

class InMemoryKoalaGuideRemoteDataSource implements KoalaGuideRemoteDataSource {
  InMemoryKoalaGuideRemoteDataSource({
    List<KoalaGuideMessage> messages = const [],
  }) {
    for (final message in messages) {
      upsertMessage(message: message, isPublished: true);
    }
  }

  final Map<String, KoalaGuideMessage> _messagesById = {};
  final Set<String> _publishedMessageIds = {};

  @override
  Future<List<KoalaGuideMessage>> getPublishedMessages() async {
    return _messagesById.values
        .where((message) => _publishedMessageIds.contains(message.id))
        .toList()
      ..sort(_sortMessages);
  }

  List<KoalaGuideMessage> getAllMessages() {
    return _messagesById.values.toList()..sort(_sortMessages);
  }

  bool isMessagePublished(String messageId) {
    return _publishedMessageIds.contains(messageId);
  }

  void upsertMessage({
    required KoalaGuideMessage message,
    required bool isPublished,
  }) {
    _messagesById[message.id] = message;
    if (isPublished) {
      _publishedMessageIds.add(message.id);
    } else {
      _publishedMessageIds.remove(message.id);
    }
  }

  void deleteMessage(String messageId) {
    _messagesById.remove(messageId);
    _publishedMessageIds.remove(messageId);
  }
}

int _sortMessages(KoalaGuideMessage a, KoalaGuideMessage b) {
  final priorityCompare = b.priority.compareTo(a.priority);
  if (priorityCompare != 0) return priorityCompare;

  final triggerCompare = a.trigger.name.compareTo(b.trigger.name);
  if (triggerCompare != 0) return triggerCompare;

  return a.id.compareTo(b.id);
}
