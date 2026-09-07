import 'llm_client.dart';

/// A scripted stand-in for a real model.
///
/// Lives in `lib/` rather than `test/` for the same reason every other
/// `InMemory*` double in this project does: the demo build wires it in when
/// there is no backend, and a test can reach it without importing test code.
///
/// Every request is kept, which is what lets a test assert on the thing that
/// actually matters about the retry loop — not that it retried, but that it
/// fed the right errors back.
class FakeLlmClient implements LlmClient {
  FakeLlmClient(this.replies);

  /// Fails every call the same way.
  FakeLlmClient.alwaysFails(LlmException failure) : replies = [failure];

  /// Consumed in order. Each entry is either the raw reply text for that
  /// call, or an [LlmException] to throw on it. Once the list runs out the
  /// last entry repeats, so a one-entry script answers any number of calls.
  final List<Object> replies;

  final List<LlmCompletionRequest> requests = [];

  int get callCount => requests.length;

  /// What was said to the model most recently — the repair message, on any
  /// call after the first.
  String get lastUserMessage => requests.isEmpty
      ? ''
      : requests.last.messages
          .lastWhere(
            (message) => message.role == LlmRole.user,
            orElse: () => const LlmMessage.user(''),
          )
          .content;

  @override
  Future<LlmCompletion> complete(LlmCompletionRequest request) async {
    requests.add(request);
    if (replies.isEmpty) {
      throw const LlmException(
        LlmFailure.badResponse,
        'FakeLlmClient was given no replies.',
      );
    }

    final index = requests.length - 1;
    final reply =
        index < replies.length ? replies[index] : replies.last;

    if (reply is LlmException) throw reply;
    return LlmCompletion(text: reply as String, finishReason: 'stop');
  }
}
