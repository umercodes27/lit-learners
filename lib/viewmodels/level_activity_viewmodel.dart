import 'package:flutter/foundation.dart';

import '../models/content_item.dart';
import '../models/learning_level.dart';

class LevelActivityViewModel extends ChangeNotifier {
  LevelActivityViewModel(this.level);

  static const defaultDrawingColors = [
    'Red',
    'Blue',
    'Yellow',
    'Green',
  ];

  final LearningLevel level;
  int _itemIndex = 0;
  int _tapCount = 0;
  String? _selectedMatch;
  String _selectedDrawingColor = defaultDrawingColors.first;
  bool _currentItemComplete = false;

  int get itemIndex => _itemIndex;
  ContentItem get currentItem => level.contentItems[_itemIndex];
  bool get currentItemComplete => _currentItemComplete;
  int get tapCount => _tapCount;
  bool get isLastItem => _itemIndex == level.contentItems.length - 1;
  bool get isActivityComplete => _currentItemComplete && isLastItem;

  int get targetCount {
    return int.tryParse(currentItem.displayText) ?? 1;
  }

  String? get selectedMatch => _selectedMatch;
  String get selectedDrawingColor => _selectedDrawingColor;
  List<String> get drawingColorOptions => defaultDrawingColors;

  List<String> get matchOptions {
    final labels =
        level.contentItems.map((item) => item.title).toSet().toList();
    if (!labels.contains(currentItem.title)) {
      labels.insert(0, currentItem.title);
    }
    return labels;
  }

  void tapCounter() {
    if (level.type != LevelType.counting || _currentItemComplete) return;

    _tapCount += 1;
    if (_tapCount >= targetCount) {
      _currentItemComplete = true;
    }
    notifyListeners();
  }

  void selectMatch(String value) {
    if (level.type != LevelType.matching || _currentItemComplete) return;

    _selectedMatch = value;
    _currentItemComplete = value == currentItem.title;
    notifyListeners();
  }

  void markCurrentLearned() {
    _currentItemComplete = true;
    notifyListeners();
  }

  void selectDrawingColor(String value) {
    if (!defaultDrawingColors.contains(value)) return;

    _selectedDrawingColor = value;
    notifyListeners();
  }

  void nextItem() {
    if (!_currentItemComplete || isLastItem) return;

    _itemIndex += 1;
    _tapCount = 0;
    _selectedMatch = null;
    _selectedDrawingColor = defaultDrawingColors.first;
    _currentItemComplete = false;
    notifyListeners();
  }

  void resetCurrentItem() {
    _tapCount = 0;
    _selectedMatch = null;
    _selectedDrawingColor = defaultDrawingColors.first;
    _currentItemComplete = false;
    notifyListeners();
  }
}
