import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/localization/urdu_letters.dart';
import 'package:little_learners/services/content/asset_availability.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/models/activity_option.dart';
import 'package:little_learners/models/activity_pack.dart';
import 'package:little_learners/views/activity_pack/activity_level_page.dart';
import 'package:little_learners/widgets/activities/playful_tap_target.dart';

import 'dart:convert';

void main() {
  group('UrduLetters', () {
    test('maps the letter names the age-2 pack actually uses', () {
      expect(UrduLetters.glyphFor('Alif'), 'ا');
      expect(UrduLetters.glyphFor('Bay'), 'ب');
      expect(UrduLetters.glyphFor('Pay'), 'پ');
      expect(UrduLetters.glyphFor('Tay'), 'ت');
      expect(UrduLetters.glyphFor('Jeem'), 'ج');
      expect(UrduLetters.glyphFor('Hay'), 'ح');
      expect(UrduLetters.glyphFor('Daal'), 'د');
      expect(UrduLetters.glyphFor('Zaal'), 'ذ');
    });

    test('ignores case, spacing and bracketed qualifiers', () {
      expect(UrduLetters.glyphFor('alif'), 'ا');
      expect(UrduLetters.glyphFor('ALIF'), 'ا');
      expect(UrduLetters.glyphFor('Tay (Te)'), 'ٹ');
      expect(UrduLetters.glyphFor('tay-te'), 'ٹ');
    });

    test('an unknown name falls through to itself rather than vanishing', () {
      expect(UrduLetters.glyphFor('Wingding'), isNull);
      expect(UrduLetters.display('Wingding'), 'Wingding');
    });

    test('recognises text that is already Urdu script', () {
      expect(UrduLetters.isUrduScript('ا'), isTrue);
      expect(UrduLetters.isUrduScript('بلی'), isTrue);
      expect(UrduLetters.isUrduScript('Alif'), isFalse);
      expect(UrduLetters.isUrduScript(null), isFalse);
    });
  });

  group('the Urdu module', () {
    test('is right-to-left even when the pack omits the flag', () {
      final pack = ActivityPack.fromJson(jsonDecode('''
        {
          "modules": {
            "urdu":    { "level_1": { "component": "two-choice-tap", "title": "U",
                          "items": [{"target":"Alif","distractor":"Bay"}] } },
            "english": { "level_1": { "component": "two-choice-tap", "title": "E",
                          "items": [{"target":"A","distractor":"B"}] } }
          }
        }
      ''') as Map<String, dynamic>);

      expect(pack.levelByKey('urdu', 'level_1')!.data.isRtl, isTrue);
      expect(pack.levelByKey('english', 'level_1')!.data.isRtl, isFalse);
    });

    test('an explicit rtl flag still wins', () {
      final pack = ActivityPack.fromJson(jsonDecode('''
        { "modules": { "urdu": { "rtl": false,
            "level_1": { "component": "two-choice-tap", "title": "U",
                         "items": [{"target":"Alif","distractor":"Bay"}] } } } }
      ''') as Map<String, dynamic>);

      expect(pack.levelByKey('urdu', 'level_1')!.data.isRtl, isFalse);
    });
  });

  group('rendering', () {
    testWidgets('an Urdu round shows the script, not the romanised name',
        (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const data = TwoChoiceTapData(
        title: 'Harf Ki Pehchan',
        isRtl: true,
        items: [
          TwoChoiceTapItem(
            options: [
              ActivityOption(label: 'Alif', isCorrect: true),
              ActivityOption(label: 'Bay'),
            ],
          ),
        ],
      );

      await tester.pumpWidget(const MaterialApp(
        home: ActivityLevelPage(
          args: ActivityLevelArgs(
            level: ActivityLevel(key: 'level_1', moduleKey: 'urdu', data: data),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('ا'), findsOneWidget);
      expect(find.text('ب'), findsOneWidget);
      expect(find.text('Alif'), findsNothing);
      expect(find.text('Bay'), findsNothing);
    });

    testWidgets('Urdu letters render in the Nastaliq face', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const data = TwoChoiceTapData(
        title: 'U',
        isRtl: true,
        items: [
          TwoChoiceTapItem(
            options: [
              ActivityOption(label: 'Jeem', isCorrect: true),
              ActivityOption(label: 'Daal'),
            ],
          ),
        ],
      );

      await tester.pumpWidget(const MaterialApp(
        home: ActivityLevelPage(
          args: ActivityLevelArgs(
            level: ActivityLevel(key: 'level_1', moduleKey: 'urdu', data: data),
          ),
        ),
      ));
      await tester.pump();

      // Fredoka carries no Arabic glyphs; falling back to it would render
      // differently on every platform.
      final glyph = tester.widget<Text>(find.text('ج'));
      expect(glyph.style?.fontFamily, 'NotoNastaliqUrdu');
    });

    testWidgets('an English round is untouched', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const data = TwoChoiceTapData(
        title: 'Letters',
        isRtl: false,
        items: [
          TwoChoiceTapItem(
            options: [
              ActivityOption(label: 'A', isCorrect: true),
              ActivityOption(label: 'M'),
            ],
          ),
        ],
      );

      await tester.pumpWidget(const MaterialApp(
        home: ActivityLevelPage(
          args: ActivityLevelArgs(
            level:
                ActivityLevel(key: 'level_1', moduleKey: 'english', data: data),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
    });
  });

  group('short windows must not blank the answers', () {
    // The bug: the answer row was Flexible, so a short window squeezed the
    // cards below their minimum height, and the Urdu glyph's line box no
    // longer fit inside one. The letter clipped away and both cards rendered
    // empty — it looked like missing content but was pure layout.
    const nuqta = IdentifyAndTapData(
      title: 'نقطوں کی پہچان',
      isRtl: true,
      items: [
        IdentifyAndTapItem(
          promptImage: 'assets/age2/img/bay_shape.png',
          options: [
            ActivityOption(label: 'Bay', isCorrect: true),
            ActivityOption(label: 'Pay'),
          ],
        ),
      ],
    );

    const shortWindows = <String, Size>{
      'wide and short': Size(1900, 700),
      'laptop window': Size(1280, 620),
      'very short': Size(1000, 520),
      'small phone': Size(320, 640),
    };

    for (final entry in shortWindows.entries) {
      testWidgets('both answers are visible on a ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // The real prompt image has to render at its real size. With the
        // manifest unloaded it degrades to a small placeholder, the answers
        // are never squeezed, and this test would pass against the bug.
        await tester.runAsync(() => AssetAvailability.instance.populate());

        await tester.pumpWidget(const MaterialApp(
          home: ActivityLevelPage(
            args: ActivityLevelArgs(
              level: ActivityLevel(
                  key: 'level_2', moduleKey: 'urdu', data: nuqta),
            ),
          ),
        ));
        await tester.pump();

        for (final glyph in ['ب', 'پ']) {
          expect(find.text(glyph), findsOneWidget,
              reason: '$glyph missing on ${entry.key}');

          // Size alone proves nothing: a clipped Text still reports its full
          // natural size. What matters is that the glyph fits inside the card
          // drawing it, which is exactly what failed before.
          final glyphRect = tester.getRect(find.text(glyph));
          final cardRect = tester.getRect(
            find
                .ancestor(
                  of: find.text(glyph),
                  matching: find.byType(PlayfulTapTarget),
                )
                .first,
          );

          expect(glyphRect.height, lessThanOrEqualTo(cardRect.height + 1),
              reason: '$glyph is taller than its card on ${entry.key}, so it '
                  'renders clipped or invisible');
          expect(glyphRect.width, lessThanOrEqualTo(cardRect.width + 1),
              reason: '$glyph is wider than its card on ${entry.key}');
          expect(cardRect.height, greaterThanOrEqualTo(80),
              reason: 'the answer card was squeezed under the tap-target '
                  'floor on ${entry.key}');
        }

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Urdu titles', () {
    testWidgets('a title written in Urdu renders in Nastaliq', (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const data = TwoChoiceTapData(
        title: 'نقطوں کی پہچان',
        isRtl: true,
        items: [
          TwoChoiceTapItem(
            options: [
              ActivityOption(label: 'Bay', isCorrect: true),
              ActivityOption(label: 'Pay'),
            ],
          ),
        ],
      );

      await tester.pumpWidget(const MaterialApp(
        home: ActivityLevelPage(
          args: ActivityLevelArgs(
            level: ActivityLevel(key: 'level_2', moduleKey: 'urdu', data: data),
          ),
        ),
      ));
      await tester.pump();

      final title = tester.widget<Text>(find.text('نقطوں کی پہچان'));
      expect(title.style?.fontFamily, 'NotoNastaliqUrdu');
    });

    testWidgets('an English title still uses Fredoka', (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const data = TwoChoiceTapData(
        title: 'Letter Choice',
        isRtl: false,
        items: [
          TwoChoiceTapItem(
            options: [
              ActivityOption(label: 'A', isCorrect: true),
              ActivityOption(label: 'M'),
            ],
          ),
        ],
      );

      await tester.pumpWidget(const MaterialApp(
        home: ActivityLevelPage(
          args: ActivityLevelArgs(
            level:
                ActivityLevel(key: 'level_1', moduleKey: 'english', data: data),
          ),
        ),
      ));
      await tester.pump();

      final title = tester.widget<Text>(find.text('Letter Choice'));
      expect(title.style?.fontFamily, 'Fredoka');
    });
  });
}
