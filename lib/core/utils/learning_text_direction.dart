import 'package:flutter/widgets.dart';

import '../../models/learning_level.dart';
import '../../models/learning_module.dart';

class LearningTextDirection {
  const LearningTextDirection._();

  static const urduFontFamily = 'NotoNastaliqUrdu';

  static TextDirection forModule(LearningModule module) {
    return module.category == ModuleCategory.urdu
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  static TextDirection forLevel(LearningLevel level) {
    return level.moduleId == 'urdu' ? TextDirection.rtl : TextDirection.ltr;
  }

  static TextDirection forText(String text) {
    return _hasArabicScript(text) ? TextDirection.rtl : TextDirection.ltr;
  }

  static TextAlign alignFor(TextDirection direction) {
    return direction == TextDirection.rtl ? TextAlign.right : TextAlign.left;
  }

  static String? fontFamilyFor(TextDirection direction) {
    return direction == TextDirection.rtl ? urduFontFamily : null;
  }

  static String? fontFamilyForText(String text) {
    return fontFamilyFor(forText(text));
  }

  static TextStyle? styleFor(TextStyle? baseStyle, TextDirection direction) {
    final fontFamily = fontFamilyFor(direction);
    if (fontFamily == null) return baseStyle;

    return (baseStyle ?? const TextStyle()).copyWith(
      fontFamily: fontFamily,
    );
  }

  static TextStyle? styleForText(TextStyle? baseStyle, String text) {
    return styleFor(baseStyle, forText(text));
  }

  static bool _hasArabicScript(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }
}
