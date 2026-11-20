import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/repository/database_backup_service.dart';
import 'package:vocabulary_trainer/repository/mobile_database_export.dart';

class FakeBackupService extends DatabaseBackupService {
  String? exportedPath;
  final validatedPaths = <String>[];
  bool invalid = false;
  static const info = DatabaseBackupInfo(
    version: 9,
    vocabularyItemCount: 12,
    studySetCount: 2,
    languageCombinationCount: 1,
    membershipCount: 15,
  );

  @override
  Future<void> exportDatabase({required String destinationPath}) async {
    exportedPath = destinationPath;
    await File(destinationPath).writeAsBytes([1, 2, 3]);
  }

  @override
  Future<DatabaseBackupInfo> validateDatabase(String filePath) async {
    validatedPaths.add(filePath);
    expect(await File(filePath).exists(), isTrue);
    if (invalid) throw const DatabaseBackupException('Invalid snapshot');
    return info;
  }
}

void main() {
  test(
    'validates snapshot before save, never reopens external destination',
    () async {
      final service = FakeBackupService();
      final info = await exportMobileDatabase(
        backupService: service,
        saveFile: (bytes) async {
          expect(service.validatedPaths, [service.exportedPath]);
          expect(bytes, [1, 2, 3]);
          // Simulates iCloud/provider destination, including replacing a file.
          return '/outside-app-sandbox/vocabulary_trainer.db';
        },
      );
      expect(info, same(FakeBackupService.info));
      expect(service.validatedPaths, [service.exportedPath]);
      expect(await File(service.exportedPath!).parent.exists(), isFalse);
    },
  );

  test('cancelled picker returns no success and cleans up snapshot', () async {
    final service = FakeBackupService();
    expect(
      await exportMobileDatabase(
        backupService: service,
        saveFile: (_) async => null,
      ),
      isNull,
    );
    expect(await File(service.exportedPath!).parent.exists(), isFalse);
  });

  test(
    'invalid snapshot is rejected before showing picker and cleaned up',
    () async {
      final service = FakeBackupService()..invalid = true;
      await expectLater(
        exportMobileDatabase(
          backupService: service,
          saveFile: (_) async => fail('Picker must not open'),
        ),
        throwsA(isA<DatabaseBackupException>()),
      );
      expect(await File(service.exportedPath!).parent.exists(), isFalse);
    },
  );

  test('picker failure propagates and cleans up snapshot', () async {
    final service = FakeBackupService();
    await expectLater(
      exportMobileDatabase(
        backupService: service,
        saveFile: (_) async => throw const FileSystemException('Save failed'),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(service.exportedPath!).parent.exists(), isFalse);
  });
}
