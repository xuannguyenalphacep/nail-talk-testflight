class ContentModerationException implements Exception {
  const ContentModerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ContentModerationUtils {
  const ContentModerationUtils._();

  static final List<RegExp> _blockedPatterns = <RegExp>[
    RegExp(r'\b(kill yourself|suicide bait)\b', caseSensitive: false),
    RegExp(r'\b(nazi|terrorist threat)\b', caseSensitive: false),
    RegExp(r'\b(child porn|cp\b|underage sex)\b', caseSensitive: false),
    RegExp(r'\b(fuck you|fucking scam|scammer)\b', caseSensitive: false),
    RegExp(r'\b(đụ mẹ|dit me|dm mày|đm mày)\b', caseSensitive: false),
    RegExp(r'\b(lừa đảo|lua dao)\b', caseSensitive: false),
  ];

  static const unsafeContentMessage =
      'This content looks unsafe for the Nails Talk community. Please edit it before posting.';

  static void validateOrThrow(Iterable<String?> values) {
    final text = values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');

    if (text.isEmpty) return;

    for (final pattern in _blockedPatterns) {
      if (pattern.hasMatch(text)) {
        throw const ContentModerationException(unsafeContentMessage);
      }
    }
  }
}
