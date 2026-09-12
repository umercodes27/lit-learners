import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/repositories/admin_content_repository.dart';
import 'package:little_learners/services/ai/ai_content_generator.dart';
import 'package:little_learners/services/ai/fake_llm_client.dart';
import 'package:little_learners/services/ai/llm_client.dart';
import 'package:little_learners/services/ai/llm_credential_store.dart';
import 'package:little_learners/services/ai/llm_provider_profile.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';
import 'package:little_learners/viewmodels/admin_content_viewmodel.dart';
import 'package:little_learners/viewmodels/ai_content_viewmodel.dart';

const reply = '{"levels":[{"title":"Big and small again",'
    '"subtitle":"Point at the big one.","passingScore":60,'
    '"contentItems":['
    '{"title":"Big ball","prompt":"Find the big ball.","displayText":"Big",'
    '"visualLabel":"A big ball"},'
    '{"title":"Small ball","prompt":"Find the small ball.",'
    '"displayText":"Small","visualLabel":"A small ball"}],'
    '"quizQuestions":[{"prompt":"Which is big?",'
    '"options":["Big ball","Small ball"],"correctIndex":0}]}]}';

void main() {
  test('rewriting a built-in level keeps its ID and takes its place',
      () async {
    final builtIn = seedLevels.firstWhere(
      (l) => l.type == LevelType.flashcards && l.moduleId != 'urdu',
    );
    final client = FakeLlmClient([reply]);
    final ai = AiContentViewModel(
      generator: AiContentGenerator(client: client),
      credentialStore: InMemoryLlmCredentialStore(
        const LlmCredentials(
          apiKey: 'sk-test',
          profile: LlmProviderProfile.deepseek,
        ),
      ),
    );
    await ai.loadCredentials();
    final admin = AdminContentViewModel(
      InMemoryAdminContentRepository(
        contentRemoteDataSource: InMemoryContentRemoteDataSource(),
      ),
    );

    ai.startRevision(builtIn);
    ai.setGuidance('Use balls.');
    await ai.generate(
      modules: [for (final m in admin.modules) m.module],
      existingLevels: [for (final l in admin.levels) l.level],
    );

    final draft = ai.drafts.single;
    expect(draft.isBlocked, isFalse,
        reason: draft.blocking.map((i) => i.message).join('\n'));
    expect(draft.level.id, builtIn.id,
        reason: 'a rewrite that landed under a new id would sit beside the '
            'original instead of replacing it');
    expect(draft.level.levelNumber, builtIn.levelNumber);
    expect(client.lastUserMessage, contains('Rewrite ONE existing level'));
    expect(client.lastUserMessage, contains('Use balls.'));

    ai.toggleApproved(0, true);
    final saved = await ai.saveRevision(
      (level) => admin.saveRevisedLevel(level, publish: true),
    );

    expect(saved, isTrue, reason: admin.errorMessage);
    expect(admin.levelById(builtIn.id)!.level.title, 'Big and small again');
    expect(admin.levelOrigin(builtIn.id), ContentOrigin.builtInEdited);
    expect(admin.levelById(builtIn.id)!.level.isBundled, builtIn.isBundled);
    expect(ai.revising, isNull);
  });
}
