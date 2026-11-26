/// Form validators. Loosened compared to the original app, which only accepted
/// gmail/yahoo/hotmail addresses and ASCII names of up to 10 characters.
abstract final class Validators {
  static String? name(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Please enter your name';
    if (s.length > 40) return 'Name is too long';
    return null;
  }

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static String? email(String? v) =>
      _email.hasMatch(v?.trim() ?? '') ? null : 'Please enter a valid email';

  static bool hasMinLength(String p) => p.length >= 8;
  static bool hasUpper(String p) => p.contains(RegExp('[A-Z]'));
  static bool hasLower(String p) => p.contains(RegExp('[a-z]'));
  static bool hasDigit(String p) => p.contains(RegExp('[0-9]'));

  static String? password(String? v) {
    final p = v ?? '';
    return hasMinLength(p) && hasUpper(p) && hasLower(p) && hasDigit(p)
        ? null
        : 'Password does not meet the requirements';
  }

  static String? Function(String?) number({required String label, required num min, required num max}) =>
      (v) {
        final n = num.tryParse(v?.trim() ?? '');
        if (n == null) return 'Enter your $label';
        if (n < min || n > max) return '$label must be between $min and $max';
        return null;
      };
}
