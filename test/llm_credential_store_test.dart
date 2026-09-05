import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/services/ai/llm_client.dart';
import 'package:little_learners/services/ai/llm_credential_store.dart';
import 'package:little_learners/services/ai/llm_provider_profile.dart';

void main() {
  group('credentials', () {
    test('an unset store is not configured', () {
      const credentials = LlmCredentials.unset();
      expect(credentials.isConfigured, isFalse);
      expect(credentials.profile.id, 'deepseek');
    });

    test('whitespace is not a key', () {
      const credentials =
          LlmCredentials(apiKey: '   ', profile: LlmProviderProfile.deepseek);
      expect(credentials.isConfigured, isFalse);
    });

    test('the mask shows enough to recognise a key and no more', () {
      const credentials = LlmCredentials(
        apiKey: 'sk-abcdefghijklmnop9f2a',
        profile: LlmProviderProfile.deepseek,
      );

      expect(credentials.maskedKey, 'sk-…9f2a');
      expect(credentials.maskedKey, isNot(contains('abcdefghijklmnop')));
    });

    test('a short key is hidden completely rather than mostly revealed', () {
      const credentials =
          LlmCredentials(apiKey: 'sk-123', profile: LlmProviderProfile.deepseek);
      expect(credentials.maskedKey, isNot(contains('123')));
    });

    test('no key reads as not set', () {
      expect(const LlmCredentials.unset().maskedKey, '(not set)');
    });
  });

  group('provider profiles', () {
    test('DeepSeek is the default and is OpenAI-shaped', () {
      const deepseek = LlmProviderProfile.deepseek;
      expect(deepseek.chatCompletionsUri.toString(),
          'https://api.deepseek.com/v1/chat/completions');
      expect(deepseek.jsonMode, LlmJsonMode.jsonObject);
    });

    test('every preset builds a chat completions url', () {
      for (final preset in LlmProviderProfile.presets) {
        final uri = preset.chatCompletionsUri;
        expect(uri.isAbsolute, isTrue, reason: preset.id);
        expect(uri.path, endsWith('/chat/completions'), reason: preset.id);
      }
    });

    test('a profile survives a round trip through storage strings', () {
      final original = LlmProviderProfile.openAi
          .copyWith(model: 'gpt-4o', jsonMode: LlmJsonMode.jsonSchema);

      final restored = LlmProviderProfile.fromMap(original.toMap());

      expect(restored.id, 'openai');
      expect(restored.model, 'gpt-4o');
      expect(restored.jsonMode, LlmJsonMode.jsonSchema);
      expect(restored.baseUrl, original.baseUrl);
    });

    test('a half-written row still resolves to something usable', () {
      final restored = LlmProviderProfile.fromMap({
        'id': 'groq',
        'baseUrl': null,
        'model': '  ',
        'jsonMode': 'nonsense',
      });

      expect(restored.id, 'groq');
      expect(restored.baseUrl, LlmProviderProfile.groq.baseUrl);
      expect(restored.model, LlmProviderProfile.groq.model);
      expect(restored.jsonMode, LlmProviderProfile.groq.jsonMode);
    });

    test('an unknown provider id falls back to the default', () {
      expect(LlmProviderProfile.presetById('made-up').id, 'deepseek');
    });
  });

  group('in-memory store', () {
    test('round trips, and clear leaves nothing', () async {
      final store = InMemoryLlmCredentialStore();
      expect((await store.read()).isConfigured, isFalse);

      await store.write(const LlmCredentials(
        apiKey: 'sk-test-key-value',
        profile: LlmProviderProfile.groq,
      ));

      final read = await store.read();
      expect(read.apiKey, 'sk-test-key-value');
      expect(read.profile.id, 'groq');

      await store.clear();
      expect((await store.read()).isConfigured, isFalse);
    });
  });
}
