/// Turns the romanised Urdu letter names a content pack is written in into the
/// script a child should actually see.
///
/// The packs name letters in Latin — `"target": "Alif"`, `"correct_letter":
/// "Bay"` — because that is what is readable to whoever authors and voices
/// them. Rendering that name on screen would be teaching a two-year-old the
/// wrong thing: the point of the Urdu module is recognising ا, not the English
/// word "Alif".
///
/// So the name stays the identifier and this is the presentation layer on top.
/// An unrecognised name falls through to itself rather than to a blank or a
/// placeholder — a new letter shows up as its Latin name, which is wrong but
/// legible, instead of vanishing.
class UrduLetters {
  const UrduLetters._();

  /// Keyed on a normalised name so `Tay (Te)`, `tay-te` and `TayTe` all land
  /// on the same entry.
  static const _byName = <String, String>{
    'alif': 'ا',
    'bay': 'ب',
    'pay': 'پ',
    'tay': 'ت',
    'tayte': 'ٹ',
    'tte': 'ٹ',
    'se': 'ث',
    'say': 'ث',
    'jeem': 'ج',
    'che': 'چ',
    'hay': 'ح',
    'baricchothihay': 'ح',
    'khay': 'خ',
    'daal': 'د',
    'ddaal': 'ڈ',
    'dde': 'ڈ',
    'zaal': 'ذ',
    'ray': 'ر',
    'rray': 'ڑ',
    'zay': 'ز',
    'zhay': 'ژ',
    'seen': 'س',
    'sheen': 'ش',
    'suad': 'ص',
    'swad': 'ص',
    'zuad': 'ض',
    'zwad': 'ض',
    'toay': 'ط',
    'toe': 'ط',
    'zoay': 'ظ',
    'zoe': 'ظ',
    'ain': 'ع',
    'ghain': 'غ',
    'fay': 'ف',
    'qaaf': 'ق',
    'kaaf': 'ک',
    'kaf': 'ک',
    'gaaf': 'گ',
    'laam': 'ل',
    'meem': 'م',
    'noon': 'ن',
    'noonghunna': 'ں',
    'wao': 'و',
    'chotihay': 'ہ',
    'dochashmihay': 'ھ',
    'hamza': 'ء',
    'chotiyay': 'ی',
    'yay': 'ی',
    'bariyay': 'ے',
  };

  /// The Urdu glyph for [name], or null when it is not a letter name this
  /// knows — including when [name] is already Urdu script.
  static String? glyphFor(String? name) {
    if (name == null || name.isEmpty) return null;
    return _byName[_normalise(name)];
  }

  /// The glyph if there is one, otherwise the name unchanged.
  static String display(String? name) => glyphFor(name) ?? (name ?? '');

  /// True when [text] already contains Arabic-script characters, so it needs
  /// no mapping and should be rendered in the Nastaliq face as authored.
  static bool isUrduScript(String? text) {
    if (text == null) return false;
    for (final unit in text.runes) {
      // Arabic block plus the Arabic Supplement and Extended-A ranges Urdu
      // draws its extra letters from.
      if ((unit >= 0x0600 && unit <= 0x06FF) ||
          (unit >= 0x0750 && unit <= 0x077F) ||
          (unit >= 0x08A0 && unit <= 0x08FF)) {
        return true;
      }
    }
    return false;
  }

  static String _normalise(String name) {
    final buffer = StringBuffer();
    for (final unit in name.toLowerCase().runes) {
      final char = String.fromCharCode(unit);
      // Drop spaces, hyphens and bracketed qualifiers so the lookup is about
      // the letter, not the punctuation an author happened to use.
      if (RegExp(r'[a-z]').hasMatch(char)) buffer.write(char);
    }
    return buffer.toString();
  }
}
