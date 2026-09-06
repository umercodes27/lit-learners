import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_pack.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/asset_availability.dart';
import 'package:little_learners/widgets/activities/activity_asset_image.dart';
import 'package:little_learners/widgets/activities/activity_audio.dart';
import 'package:little_learners/widgets/activities/activity_player.dart';

/// Renders the real levels and asserts pictures actually reach the screen.
///
/// The bundle tests prove the files exist and the paths resolve; these prove
/// the widgets draw them rather than falling through to the missing-asset
/// placeholder, which is the difference the user sees.
///
/// Loading goes through [WidgetTester.runAsync]: reading the asset manifest is
/// real I/O, and awaiting it inside the test's fake-async zone deadlocks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ActivityPack> loadPack(WidgetTester tester) async {
    ActivityPack? pack;
    await tester.runAsync(() async {
      await AssetAvailability.instance.populate();
      pack = (await ActivityPackLoader().load()).pack;
    });
    return pack!;
  }

  testWidgets('a picture round draws real images, not placeholders',
      (tester) async {
    final pack = await loadPack(tester);

    // Shadow matching is all pictures: one object plus two silhouettes.
    final data = pack.levelByKey('logic', 'level_1')!.data;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ActivityPlayer(data: data, audio: ActivityAudio())),
    ));
    await tester.pump();

    expect(find.byType(Image), findsWidgets,
        reason: 'no Image widgets rendered at all');
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing,
        reason: 'a picture fell through to the missing-asset placeholder');
  });

  testWidgets('the placeholder appears only for a genuinely absent file',
      (tester) async {
    await tester.runAsync(() => AssetAvailability.instance.populate());

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          ActivityAssetImage(path: 'assets/age2/img/cat.png', size: 60),
          ActivityAssetImage(path: 'assets/age2/img/not_real.png', size: 60),
        ]),
      ),
    ));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('every png the pack references resolves', (tester) async {
    final pack = await loadPack(tester);

    final unresolved = <String>[];
    for (final module in pack.modules) {
      for (final level in module.levels) {
        for (final path in level.data.referencedAssets) {
          if (!path.endsWith('.png')) continue;
          if (!AssetAvailability.instance.has(path)) {
            unresolved.add('${module.key}/${level.key}: $path');
          }
        }
      }
    }
    expect(unresolved, isEmpty);
  });
}
