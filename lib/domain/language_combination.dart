class LanguageCombination {
  final int? id;
  final String sourceLanguage;
  final String targetLanguage;

  const LanguageCombination({
    this.id,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  LanguageCombination copyWith({
    int? id,
    String? sourceLanguage,
    String? targetLanguage,
  }) {
    return LanguageCombination(
      id: id ?? this.id,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
    );
  }
}