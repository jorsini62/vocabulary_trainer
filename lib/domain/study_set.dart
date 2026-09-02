class StudySet {
  final int? id;

  final int languageCombinationId;

  final String name;

  final int standardLearningWindowSize;

  final int intenseLearningWindowSize;

  final int minimumInterval;

  final bool isDefaultStudySet;

  const StudySet({
    this.id,
    required this.languageCombinationId,
    required this.name,
    required this.standardLearningWindowSize,
    required this.intenseLearningWindowSize,
    required this.minimumInterval,
    required this.isDefaultStudySet,
  });

  StudySet copyWith({
    int? id,
    int? languageCombinationId,
    String? name,
    int? standardLearningWindowSize,
    int? intenseLearningWindowSize,
    int? minimumInterval,
    bool? isDefaultStudySet,
  }) {
    return StudySet(
      id: id ?? this.id,
      languageCombinationId:
          languageCombinationId ?? this.languageCombinationId,
      name: name ?? this.name,
      standardLearningWindowSize:
          standardLearningWindowSize ?? this.standardLearningWindowSize,

      intenseLearningWindowSize:
          intenseLearningWindowSize ?? this.intenseLearningWindowSize,

      minimumInterval: minimumInterval ?? this.minimumInterval,
      isDefaultStudySet: isDefaultStudySet ?? this.isDefaultStudySet,
    );
  }
}
