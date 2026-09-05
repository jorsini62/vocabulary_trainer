class Configuration {
  final int id;
  final int? currentLanguagePairId;
  final int? currentStudySetId;

  const Configuration({
    required this.id,
    required this.currentLanguagePairId,
    required this.currentStudySetId,
  });
}
