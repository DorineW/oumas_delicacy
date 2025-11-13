class PhoneUtils {
  // Normalize Kenyan numbers to E.164 +2547XXXXXXXX or +2541XXXXXXXX
  static String normalizeKenyan(String input) {
    final cleaned = input
        .trim()
        .replaceAll(RegExp(r"[\s\-()]+"), "")
        .replaceAll(RegExp(r"^00"), "+");

    // Already in +254 and correct length
    if (cleaned.startsWith('+254') && cleaned.length == 13) {
      return cleaned;
    }

    // Remove all non-digits
    final digits = cleaned.replaceAll(RegExp(r"\D"), "");

    // Starts with country code without '+': 2547/2541 + 8 more = 12 digits
    if (digits.startsWith('254') && digits.length == 12) {
      return '+$digits';
    }

    // Local 07xxxxxxxx or 01xxxxxxxx (10 digits)
    if (digits.length == 10 && (digits.startsWith('07') || digits.startsWith('01'))) {
      return '+254${digits.substring(1)}';
    }

    // Short 7xxxxxxxx or 1xxxxxxxx (9 digits)
    if (digits.length == 9 && (digits.startsWith('7') || digits.startsWith('1'))) {
      return '+254$digits';
    }

    // If it already starts with +254 but wrong length, attempt best-effort fix
    if (cleaned.startsWith('+254')) {
      final tail = cleaned.substring(4).replaceAll(RegExp(r"\D"), "");
      if (tail.length == 9) return '+254$tail';
    }

    // Fallback: return as-is (caller can validate and show error)
    return input.trim();
  }

  // Convert stored +254XXXXXXXXX to local display 0XXXXXXXXX
  static String toLocalDisplay(String stored) {
    final s = stored.trim();
    if (s.startsWith('+254') && s.length >= 13) {
      final tail = s.substring(4);
      if (tail.length >= 9) {
        return '0${tail.substring(tail.length - 9)}';
      }
    }
    // If already looks local 0XXXXXXXXX, return
    if (RegExp(r'^0[17]\d{8}$').hasMatch(s)) return s;
    // If digits only and 9 starting with 7/1
    final digits = s.replaceAll(RegExp(r"\D"), "");
    if (digits.length == 9 && (digits.startsWith('7') || digits.startsWith('1'))) {
      return '0$digits';
    }
    return s;
  }

  static bool isE164Kenyan(String value) {
    return RegExp(r'^\+254[17]\d{8}$').hasMatch(value);
  }
}
