import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/views/child_dashboard/widgets/level_map.dart';

void main() {
  test('every subject gets a road of its own', () {
    const modules = [
      'english',
      'math',
      'urdu',
      'logic',
      'story',
      'drawing',
      'tracing',
      'video',
    ];

    final roads = <String>{};
    for (final id in modules) {
      final shape = MapShape.forModule(id);
      roads.add(
        '${shape.amplitude}/${shape.frequency}/${shape.phase}/${shape.spacing}',
      );
    }

    // The whole point of deriving the shape from the id: two subjects should
    // not be the same road in two colours.
    expect(roads, hasLength(modules.length));
  });

  test('a module keeps the same road every time it is opened', () {
    final first = MapShape.forModule('english');
    final second = MapShape.forModule('english');

    expect(first.amplitude, second.amplitude);
    expect(first.frequency, second.frequency);
    expect(first.phase, second.phase);
    expect(first.spacing, second.spacing);
  });

  test('however far the road swings, a stop still fits on screen', () {
    const width = 358.0;
    const stopWidth = 196.0;

    for (final id in ['english', 'math', 'urdu', 'story', 'tracing']) {
      final points = MapShape.forModule(id).pointsFor(
        count: 8,
        width: width,
        inset: stopWidth,
        topPadding: 62,
        mirror: false,
      );

      for (final point in points) {
        expect(point.dx - stopWidth / 2, greaterThanOrEqualTo(-0.01),
            reason: id);
        expect(point.dx + stopWidth / 2, lessThanOrEqualTo(width + 0.01),
            reason: id);
      }
    }
  });

  test('Urdu runs the other way', () {
    const width = 358.0;
    final ltr = MapShape.forModule('urdu').pointsFor(
      count: 4, width: width, inset: 196, topPadding: 62, mirror: false,
    );
    final rtl = MapShape.forModule('urdu').pointsFor(
      count: 4, width: width, inset: 196, topPadding: 62, mirror: true,
    );

    for (var i = 0; i < ltr.length; i++) {
      expect(rtl[i].dx, closeTo(width - ltr[i].dx, 0.001));
      expect(rtl[i].dy, ltr[i].dy);
    }
  });
}
