import 'llm_provider_profile.dart';

enum LlmRole { system, user, assistant }

class LlmMessage {
  const LlmMessage(this.role, this.content);

  const LlmMessage.system(this.content) : role = LlmRole.system;
  const LlmMessage.user(this.content) : role = LlmRole.user;
  const LlmMessage.assistant(this.content) : role = LlmRole.assistant;

  final LlmRole role;
  final String content;

  Map<String, Object?> toWireMap() => {
        'role': role.name,
        'content': content,
      };
}

/// What shape of reply to ask for.
///
/// An app-level idea rather than an OpenAI field, so an adapter for a
/// differently-shaped API maps it onto whatever that provider calls the same
/// thing instead of having to understand `response_format`.
enum LlmResponseFormat { text, jsonObject }

class LlmCompletionRequest {
  const LlmCompletionRequest({
    required this.messages,
    this.temperature = 0.4,
    this.maxTokens,
    this.responseFormat = LlmResponseFormat.jsonObject,
  });

  final List<LlmMessage> messages;
  final double temperature;
  final int? maxTokens;
  final LlmResponseFormat responseFormat;

  LlmCompletionRequest followedBy(List<LlmMessage> more) =>
      LlmCompletionRequest(
        messages: [...messages, ...more],
        temperature: temperature,
        maxTokens: maxTokens,
        responseFormat: responseFormat,
      );
}

class LlmCompletion {
  const LlmCompletion({
    required this.text,
    this.promptTokens,
    this.completionTokens,
    this.finishReason,
  });

  final String text;
  final int? promptTokens;
  final int? completionTokens;

  /// `length` here means the reply was cut off mid-JSON, which is worth
  /// telling the admin apart from a model that simply wrote nonsense.
  final String? finishReason;

  bool get wasTruncated => finishReason == 'length';
}

enum LlmFailure {
  missingKey,
  unauthorized,
  rateLimited,
  timeout,
  network,
  badResponse,
  serverError,
}

class LlmException implements Exception {
  const LlmException(this.kind, this.message, {this.statusCode});

  final LlmFailure kind;
  final String message;
  final int? statusCode;

  /// Whether trying the same request again could plausibly work. A bad key
  /// will still be bad in thirty seconds, so retrying it only burns the
  /// admin's time; a rate limit or a dropped connection will not.
  bool get isRetryable =>
      kind == LlmFailure.rateLimited ||
      kind == LlmFailure.timeout ||
      kind == LlmFailure.network ||
      kind == LlmFailure.serverError;

  @override
  String toString() => message;
}

/// One call to a language model.
///
/// Deliberately the whole surface. Everything above this line — the prompt,
/// the retry loop, validation, the review screen — is testable with a fake
/// that implements this and nothing else.
abstract class LlmClient {
  Future<LlmCompletion> complete(LlmCompletionRequest request);
}

/// The key plus which service it belongs to.
class LlmCredentials {
  const LlmCredentials({required this.apiKey, required this.profile});

  const LlmCredentials.unset()
      : apiKey = '',
        profile = LlmProviderProfile.deepseek;

  final String apiKey;
  final LlmProviderProfile profile;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// For display. The key itself is never rendered — an admin needs to
  /// recognise which key is stored, not read it back.
  String get maskedKey {
    final key = apiKey.trim();
    if (key.isEmpty) return '(not set)';
    if (key.length < 12) return '•' * 8;
    return '${key.substring(0, 3)}…${key.substring(key.length - 4)}';
  }

  LlmCredentials copyWith({String? apiKey, LlmProviderProfile? profile}) =>
      LlmCredentials(
        apiKey: apiKey ?? this.apiKey,
        profile: profile ?? this.profile,
      );
}
