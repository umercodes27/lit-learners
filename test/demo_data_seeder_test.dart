import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/services/demo/demo_data_seeder.dart';
import 'package:little_learners/services/demo/demo_families.dart';
import 'package:little_learners/services/local/child_profile_dao.dart';
import 'package:little_learners/services/local/progress_dao.dart';

({
  DemoDataSeeder seeder,
  InMemoryAuthRepository auth,
  InMemoryChildProfileDao profiles,
  InMemoryProgressDao progress,
}) build() {
  final auth = InMemoryAuthRepository();
  final profiles = InMemoryChildProfileDao();
  final progress = InMemoryProgressDao();

  return (
    seeder: DemoDataSeeder(
      authRepository: auth,
      childProfileDao: profiles,
      progressDao: progress,
      contentRepository: SeedContentRepository(),
    ),
    auth: auth,
    profiles: profiles,
    progress: progress,
  );
}

void main() {
  test('the table is internally consistent', () {
    for (final family in demoFamilies) {
      expect(family.childNames.length, family.childAges.length,
          reason: '${family.email} has names and ages out of step');
      for (final age in family.childAges) {
        expect(age, inInclusiveRange(1, 4),
            reason: 'the app is for ages 1 to 4');
      }
    }

    expect(demoFamilies.map((f) => f.email).toSet(), hasLength(18),
        reason: 'emails are the account key and must be unique');
    expect(demoChildCount, 24);
  });

  test('it seeds every family and child into the real stores', () async {
    final world = build();
    await world.seeder.seed();

    expect(await world.auth.allParents(), hasLength(18));
    expect(await world.profiles.getAll(), hasLength(24));
  });

  test('three families have no child, which is the point of them', () async {
    final world = build();
    await world.seeder.seed();

    final parents = await world.auth.allParents();
    final childless = <String>[];
    for (final parent in parents) {
      final children = await world.profiles.getByParent(parent.id);
      if (children.isEmpty) childless.add(parent.email);
    }

    // The accounts chart exists to surface exactly this bucket, so a demo
    // without it would hide the finding the screen was built to show.
    expect(childless, hasLength(3));
  });

  test('seeding does not sign anybody in', () async {
    final world = build();
    await world.seeder.seed();

    // signUp signs the new account in, which would leave the app logged in as
    // whichever invented family was added last.
    expect(await world.auth.currentParent(), isNull);
  });

  test('running twice changes nothing', () async {
    final world = build();
    await world.seeder.seed();
    final firstProgress = (await world.progress.getAll()).length;

    await world.seeder.seed();

    expect(await world.auth.allParents(), hasLength(18));
    expect(await world.profiles.getAll(), hasLength(24));
    expect(await world.progress.getAll(), hasLength(firstProgress));
  });

  test('children get history, and not all of it finished', () async {
    final world = build();
    await world.seeder.seed();

    final progress = await world.progress.getAll();
    expect(progress, isNotEmpty);

    final completed = progress.where((p) => p.completed).length;
    expect(completed, greaterThan(0));
    expect(completed, lessThan(progress.length),
        reason: 'a completion rate of 100% would make the statistic '
            'meaningless, and the parent report would have nothing to call '
            'paused');
  });

  test('every progress row points at a real child and a real level', () async {
    final world = build();
    await world.seeder.seed();

    final childIds = (await world.profiles.getAll()).map((c) => c.id).toSet();
    final content = SeedContentRepository();

    for (final row in await world.progress.getAll()) {
      expect(childIds, contains(row.childId));
      expect(await content.getLevelById(row.levelId), isNotNull,
          reason: '${row.levelId} is not a level that exists');
    }
  });

  test('a demo family can be signed into with the shared password', () async {
    final world = build();
    await world.seeder.seed();

    final parent = await world.auth.signIn(
      email: demoFamilies.first.email,
      password: DemoDataSeeder.demoPassword,
    );

    expect(parent.email, demoFamilies.first.email);
  });
}
