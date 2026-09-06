import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/asset_availability.dart';

/// Checks the shipped age-2 pack against the assets actually bundled.
///
/// The unit tests all run against a fake bundle, which cannot catch a pubspec
/// that forgot a folder or a manifest that does not load — the two failures
/// that leave every picture as a placeholder with nothing logged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the asset manifest loads and lists the age-2 media', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    final age2 = assets.where((a) => a.startsWith('assets/age2/')).toList();
    expect(age2, isNotEmpty,
        reason: 'pubspec is not bundling assets/age2 at all');
    expect(age2, contains('assets/age2/img/cat.png'));
    expect(age2, contains('assets/age2/audio/sfx/applause.mp3'));
    expect(age2, contains('assets/age2/img/ur/billi.png'));
  });

  test('AssetAvailability reports itself populated from the real bundle',
      () async {
    final availability = AssetAvailability.instance;
    await availability.populate();

    expect(availability.isKnown, isTrue,
        reason: 'populate() failed, so has() answers true for everything and '
            'no rebase or missing-asset report can happen');
    expect(availability.has('assets/age2/img/cat.png'), isTrue);
    expect(availability.has('assets/age2/img/does_not_exist.png'), isFalse);
  });

  test('every path in the shipped pack resolves to a real bundled asset',
      () async {
    final result = await ActivityPackLoader().load();

    expect(result.error, isNull);
    expect(result.pack, isNotNull);

    expect(result.missingAssets, isEmpty);

    // Every path must be one the bundle really has.
    for (final path in result.pack!.referencedAssets) {
      expect(AssetAvailability.instance.has(path), isTrue,
          reason: '$path is referenced but not bundled');
    }
  });

  test('the pack still exposes all five modules and their levels', () async {
    final result = await ActivityPackLoader().load();
    final pack = result.pack!;

    expect(
      pack.modules.map((m) => m.key),
      containsAll(<String>['english', 'urdu', 'math', 'logic', 'storytelling']),
    );
    for (final module in pack.modules) {
      for (final level in module.levels) {
        expect(level.data.isEmpty, isFalse,
            reason: '${module.key}/${level.key} parsed to nothing');
        expect(level.data.component, isNot(ActivityComponent.unknown),
            reason: '${module.key}/${level.key} has an unknown component');
      }
    }
  });
}
