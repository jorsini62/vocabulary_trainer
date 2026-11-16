import '../domain/vocabulary_item.dart';

/// A comparison key only: stored and displayed expressions remain untouched.
/// Handles precomposed Latin macron vowels and combining macrons (U+0304).
/// Other accents and expression whitespace are intentionally preserved.
String normalizeVocabularyExpression(String expression) {
  const vowels = {'ā': 'a', 'ē': 'e', 'ī': 'i', 'ō': 'o', 'ū': 'u', 'ȳ': 'y'};
  return expression.toLowerCase().split('').map((character) {
    if (character == '\u0304') return '';
    return vowels[character] ?? character;
  }).join();
}

/// Full normalized source expression, then original spelling and persistent ID.
/// Target text provides a final deterministic fallback for unsaved items.
int compareVocabularyForListing(VocabularyItem a, VocabularyItem b) {
  final normalized = normalizeVocabularyExpression(
    a.sourceExpression,
  ).compareTo(normalizeVocabularyExpression(b.sourceExpression));
  if (normalized != 0) return normalized;
  final spelling = a.sourceExpression.compareTo(b.sourceExpression);
  if (spelling != 0) return spelling;
  if (a.id != b.id) {
    if (a.id == null) return 1;
    if (b.id == null) return -1;
    return a.id!.compareTo(b.id!);
  }
  return a.targetExpression.compareTo(b.targetExpression);
}

/// Shared presentation pipeline for desktop and mobile management lists.
/// Returns a new list; repository/learning order and original items are intact.
List<VocabularyItem> filterVocabularyForListing(
  Iterable<VocabularyItem> items,
  String search,
) {
  final prefix = normalizeVocabularyExpression(search.trim());
  return items.where((item) {
    return prefix.isEmpty ||
        normalizeVocabularyExpression(
          item.sourceExpression,
        ).startsWith(prefix) ||
        normalizeVocabularyExpression(item.targetExpression).startsWith(prefix);
  }).toList()..sort(compareVocabularyForListing);
}
