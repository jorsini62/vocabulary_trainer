class Configuration {
  final int id;
  final int? currentLanguagePairId;
  final int? currentStudySetId;
  final String? backupLocation;
  final String? backupBookmark;

  const Configuration({
    required this.id,
    required this.currentLanguagePairId,
    required this.currentStudySetId,
    this.backupLocation,
    this.backupBookmark,
  });

  Configuration copyWith({
    int? id,
    int? currentLanguagePairId,
    int? currentStudySetId,
    String? backupLocation,
    String? backupBookmark,
    bool clearBackupLocation = false,
    bool clearBackupBookmark = false,
  }) {
    return Configuration(
      id: id ?? this.id,
      currentLanguagePairId:
          currentLanguagePairId ?? this.currentLanguagePairId,
      currentStudySetId: currentStudySetId ?? this.currentStudySetId,
      backupLocation: clearBackupLocation
          ? null
          : (backupLocation ?? this.backupLocation),
      backupBookmark: clearBackupBookmark
          ? null
          : (backupBookmark ?? this.backupBookmark),
    );
  }
}
