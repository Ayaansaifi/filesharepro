/// Phone-number normalization helpers.
///
/// In FileShare Pro, a phone number (in normalized form) is the **peer address**
/// used for internet (WebRTC) chat. Both devices must agree on the exact same
/// string for a given contact, otherwise signaling topics won't match.
///
/// We normalize to digits-only (with a leading country code) because that is the
/// most stable representation we can derive locally without a phone library:
/// it matches `flutter_contacts` `normalizedNumber` for most carriers.
class PhoneUtils {
  PhoneUtils._();

  /// Normalize a raw phone string to a digits-only representation.
  ///
  /// Strips spaces, dashes, parentheses and a leading "+".
  /// Examples:
  ///   "+91 98765 43210"  -> "919876543210"
  ///   "(555) 123-4567"   -> "5551234567"      (no country code)
  ///   "00 1 415 555 0100"-> "0014155550100"   (00 kept as-is, treated as digits)
  static String normalize(String raw) {
    if (raw.isEmpty) return '';
    // Keep digits only.
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    return digits;
  }

  /// Validate that a normalized number is usable as a peer address.
  /// We require at least 7 digits to avoid obviously bad input.
  static bool isValid(String normalized) {
    return normalized.length >= 7 && RegExp(r'^\d+$').hasMatch(normalized);
  }

  /// Try to derive a peer id from a raw phone string.
  /// Returns null if the input cannot be normalized to a valid number.
  static String? tryPeerId(String raw) {
    final n = normalize(raw);
    return isValid(n) ? n : null;
  }
}
