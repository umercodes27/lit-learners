import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'llm_client.dart';
import 'llm_credential_store.dart';
import 'llm_provider_profile.dart';

/// Talks to any service that speaks OpenAI's `/chat/completions` shape.
///
/// That covers DeepSeek, OpenAI, Groq and most hosted models, so one client
/// and two configuration strings reach all of them. This is the only file in
/// the app that makes an HTTP request of its own; everything else goes
/// through Firebase.
///
/// It holds the credential *store* rather than a key, so an admin changing
/// their key takes effect on the next call instead of on the next restart.
class OpenAiCompatibleLlmClient implements LlmClient {
  OpenAiCompatibleLlmClient({
    required LlmCredentialStore credentialStore,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 120),
  })  : _credentialStore = credentialStore,
        _http = httpClient ?? http.Client();

  final LlmCredentialStore _credentialStore;
  final http.Client _http;

  /// Generous on purpose. Five levels of Urdu is thousands of tokens and a
  /// minute is normal; a short timeout here just turns a slow success into a
  /// failure the admin pays for twice.
  final Duration timeout;

  @override
  Future<LlmCompletion> complete(LlmCompletionRequest request) async {
    final credentials = await _credentialStore.read();
    if (!credentials.isConfigured) {
      throw const LlmException(
        LlmFailure.missingKey,
        'Add an API key before generating.',
      );
    }

    final profile = credentials.profile;
    final body = <String, Object?>{
      'model': profile.model,
      'messages': [for (final m in request.messages) m.toWireMap()],
      'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
      // Only sent when the provider actually honours it. This is the single
      // place OpenAI's wire shape leaks, which is what keeps the rest of the
      // pipeline provider-agnostic.
      if (request.responseFormat == LlmResponseFormat.jsonObject &&
          profile.jsonMode != LlmJsonMode.none)
        'response_format': const {'type': 'json_object'},
    };

    final http.Response response;
    try {
      response = await _http
          .post(
            profile.chatCompletionsUri,
            headers: {
              'Authorization': 'Bearer ${credentials.apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw LlmException(
        LlmFailure.timeout,
        '${profile.label} did not reply within '
        '${timeout.inSeconds} seconds.',
      );
    } on SocketException catch (error) {
      throw LlmException(
        LlmFailure.network,
        'Could not reach ${profile.label}: ${error.message}',
      );
    } on http.ClientException catch (error) {
      throw LlmException(
        LlmFailure.network,
        'Could not reach ${profile.label}: ${error.message}',
      );
    }

    if (response.statusCode != 200) {
      throw _failure(response, profile);
    }

    return _completion(response, profile);
  }

  LlmException _failure(http.Response response, LlmProviderProfile profile) {
    final detail = _errorMessage(response.body) ?? response.reasonPhrase ?? '';
    final code = response.statusCode;

    final kind = switch (code) {
      401 || 403 => LlmFailure.unauthorized,
      429 => LlmFailure.rateLimited,
      >= 500 => LlmFailure.serverError,
      _ => LlmFailure.badResponse,
    };

    final message = switch (kind) {
      LlmFailure.unauthorized =>
        '${profile.label} rejected the API key. Check it is correct and still '
            'active.',
      LlmFailure.rateLimited =>
        '${profile.label} is rate limiting this key. Wait a moment and try '
            'again.',
      LlmFailure.serverError =>
        '${profile.label} had a server error ($code). This is their end, not '
            'the key.',
      _ => '${profile.label} refused the request ($code)'
          '${detail.isEmpty ? '' : ': $detail'}',
    };

    return LlmException(kind, message, statusCode: code);
  }

  /// Providers disagree about error envelopes, so this reads the common
  /// shapes and gives up quietly rather than failing while reporting a
  /// failure.
  String? _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final error = decoded['error'];
      if (error is String) return error;
      if (error is Map) return error['message']?.toString();
      return decoded['message']?.toString();
    } on Object {
      return null;
    }
  }

  LlmCompletion _completion(
    http.Response response,
    LlmProviderProfile profile,
  ) {
    final Object? decoded;
    try {
      // Read as UTF-8 explicitly: http defaults to latin-1 when a provider
      // omits the charset, which would turn every Urdu reply into mojibake.
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on Object {
      throw LlmException(
        LlmFailure.badResponse,
        '${profile.label} returned something that was not JSON.',
      );
    }

    if (decoded is! Map) {
      throw LlmException(
        LlmFailure.badResponse,
        '${profile.label} returned an unexpected reply.',
      );
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw LlmException(
        LlmFailure.badResponse,
        '${profile.label} returned no completion.',
      );
    }

    final first = choices.first;
    final message = first is Map ? first['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String) {
      throw LlmException(
        LlmFailure.badResponse,
        '${profile.label} returned a completion with no text.',
      );
    }

    final usage = decoded['usage'];
    return LlmCompletion(
      text: content,
      promptTokens: usage is Map ? (usage['prompt_tokens'] as num?)?.toInt() : null,
      completionTokens:
          usage is Map ? (usage['completion_tokens'] as num?)?.toInt() : null,
      finishReason: first is Map ? first['finish_reason'] as String? : null,
    );
  }
}
