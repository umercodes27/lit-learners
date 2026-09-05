import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/models/activity_pack.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/asset_availability.dart';
import 'package:little_learners/views/activity_pack/activity_level_page.dart';
import 'package:little_learners/widgets/activities/activity_asset_image.dart';

/// Proves the "Big vs Small" rounds really do draw one picture at two
/// different on-screen sizes.
///
/// The parse-level test only checks the scale numbers. This renders the level
/// and measures the pictures, which is the thing a child actually sees — and
/// the failure it guards against (two identical pictures, so the round is a
/// coin toss) would be invisible to a data test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dog, cat, car and duck render at two visible sizes',
      (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late ActivityPack pack;
    await tester.runAsync(() async {
      await AssetAvailability.instance.populate();
      pack = (await ActivityPackLoader().load()).pack!;
    });

    final data = pack.levelByKey('math', 'level_3')!.data as TwoChoiceTapData;

    // Rounds 3-6 are the ones that reuse a single picture.
    for (var round = 2; round < data.items.length; round++) {
      final item = data.items[round];

      await tester.pumpWidget(MaterialApp(
        home: ActivityLevelPage(
          args: ActivityLevelArgs(
            level: ActivityLevel(
              key: 'level_3',
              moduleKey: 'math',
              data: TwoChoiceTapData(
                title: 'Big vs Small',
                isRtl: false,
                items: [item],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      final images = tester
          .widgetList<ActivityAssetImage>(find.byType(ActivityAssetImage))
          .where((w) => w.path != null && w.path!.endsWith('.png'))
          .toList();

      expect(images.length, 2, reason: 'round $round should show two pictures');
      expect(images[0].path, images[1].path,
          reason: 'round $round should reuse one picture');

      final sizes = images.map((w) => w.size ?? 0).toList()..sort();
      expect(sizes.first, greaterThan(0));
      expect(sizes.last / sizes.first, greaterThanOrEqualTo(1.8),
          reason: 'round $round draws both at ${sizes.first} and ${sizes.last} '
              '- a child cannot tell which is bigger');
    }
  });

  testWidgets('the elephant and ball rounds still use their own two files',
      (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late ActivityPack pack;
    await tester.runAsync(() async {
      await AssetAvailability.instance.populate();
      pack = (await ActivityPackLoader().load()).pack!;
    });

    final data = pack.levelByKey('math', 'level_3')!.data as TwoChoiceTapData;

    await tester.pumpWidget(MaterialApp(
      home: ActivityLevelPage(
        args: ActivityLevelArgs(
          level: ActivityLevel(
            key: 'level_3',
            moduleKey: 'math',
            data: TwoChoiceTapData(
              title: 'Big vs Small',
              isRtl: false,
              items: [data.items.first],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final images = tester
        .widgetList<ActivityAssetImage>(find.byType(ActivityAssetImage))
        .where((w) => w.path != null && w.path!.endsWith('.png'))
        .toList();

    expect(images.length, 2);
    expect(images[0].path, isNot(images[1].path),
        reason: 'elephant ships a big and a small file');
    // Two files carry their own size difference, so both draw at full size.
    expect(images[0].size, images[1].size);
  });
}
