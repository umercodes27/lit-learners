/// How hard a provider can be made to guarantee the shape of its reply.
enum LlmJsonMode {
  /// Nothing but the prompt. Whatever comes back comes back.
  none,

  /// The provider guarantees valid JSON, but not that it matches our schema.
  /// DeepSeek and most OpenAI-compatible services sit here.
  jsonObject,

  /// The provider enforces a supplied JSON schema, so missing fields and
  /// wrong types become impossible and only meaning can be wrong.
  jsonSchema,
}

/// Which service to call, and what it can be asked to promise.
///
/// Everything provider-shaped lives here rather than in the client or the
/// request, which is what lets an Anthropic or Gemini adapter be added later
/// without touching a single call site.
class LlmProviderProfile {
  const LlmProviderProfile({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.model,
    required this.jsonMode,
    this.keyHint = '',
  });

  final String id;
  final String label;

  /// Root of the API, with no trailing slash. `/chat/completions` is appended.
  final String baseUrl;
  final String model;
  final LlmJsonMode jsonMode;

  /// Shown under the key field so an admin can tell they pasted the right one.
  final String keyHint;

  /// The default. Cheap, and its API is OpenAI-shaped, so the same client
  /// reaches OpenAI, Groq and most other services by changing two strings.
  static const deepseek = LlmProviderProfile(
    id: 'deepseek',
    label: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    model: 'deepseek-chat',
    jsonMode: LlmJsonMode.jsonObject,
    keyHint: 'Starts with sk-. From platform.deepseek.com.',
  );

  static const openAi = LlmProviderProfile(
    id: 'openai',
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4o-mini',
    jsonMode: LlmJsonMode.jsonObject,
    keyHint: 'Starts with sk-. From platform.openai.com.',
  );

  static const groq = LlmProviderProfile(
    id: 'groq',
    label: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    model: 'llama-3.3-70b-versatile',
    jsonMode: LlmJsonMode.jsonObject,
    keyHint: 'Starts with gsk_. From console.groq.com.',
  );

  static const presets = <LlmProviderProfile>[deepseek, openAi, groq];

  static LlmProviderProfile presetById(String id) => presets.firstWhere(
        (preset) => preset.id == id,
        orElse: () => deepseek,
      );

  Uri get chatCompletionsUri => Uri.parse('$baseUrl/chat/completions');

  LlmProviderProfile copyWith({
    String? baseUrl,
    String? model,
    LlmJsonMode? jsonMode,
  }) {
    return LlmProviderProfile(
      id: id,
      label: label,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      jsonMode: jsonMode ?? this.jsonMode,
      keyHint: keyHint,
    );
  }

  Map<String, String> toMap() => {
        'id': id,
        'baseUrl': baseUrl,
        'model': model,
        'jsonMode': jsonMode.name,
      };

  /// Rebuilds from stored strings, falling back to the matching preset for
  /// anything missing or unrecognised so a half-written row still resolves.
  factory LlmProviderProfile.fromMap(Map<String, String?> map) {
    final preset = presetById(map['id'] ?? deepseek.id);
    return preset.copyWith(
      baseUrl: _nonEmpty(map['baseUrl']),
      model: _nonEmpty(map['model']),
      jsonMode: LlmJsonMode.values
          .where((mode) => mode.name == map['jsonMode'])
          .firstOrNull,
    );
  }

  static String? _nonEmpty(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value.trim();
}
