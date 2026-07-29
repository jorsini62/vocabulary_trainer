class StudySet {
  final int? id;

  final String sourceLanguage;
  final String targetLanguage;

  final String name;

  final int learningWindowSize;

  const StudySet({
  this.id,
  required this.sourceLanguage,
  required this.targetLanguage,
  required this.name,
  required this.learningWindowSize,
});

  StudySet copyWith({
  int? id,
  String? sourceLanguage,
  String? targetLanguage,
  String? name,
  int? learningWindowSize,
}) {
  return StudySet(
    id: id ?? this.id,
    sourceLanguage: sourceLanguage ?? this.sourceLanguage,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    name: name ?? this.name,
    learningWindowSize:
        learningWindowSize ?? this.learningWindowSize,
  );
}
}