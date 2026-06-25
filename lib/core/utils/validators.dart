class Validators {
  const Validators._();

  static String? email(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Email is required.';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(trimmed)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String value) {
    if (value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Use at least 8 characters.';
    if (!RegExp('[A-Z]').hasMatch(value)) {
      return 'Add at least one uppercase letter.';
    }
    if (!RegExp('[0-9]').hasMatch(value)) {
      return 'Add at least one number.';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Add at least one special character.';
    }
    return null;
  }

  static String? loginPassword(String value) {
    if (value.isEmpty) return 'Password is required.';
    return null;
  }

  static String? requiredText(String value, String fieldName) {
    if (value.trim().isEmpty) return '$fieldName is required.';
    return null;
  }
}
