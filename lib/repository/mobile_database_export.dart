import 'dart:io';
import 'dart:typed_data';

import 'database_backup_service.dart';

/// Exports validated bytes through the system document picker. Its returned
/// destination may be outside the sandbox; never reopen it as a local file.
Future<DatabaseBackupInfo?> exportMobileDatabase({
  required DatabaseBackupService backupService,
  required Future<String?> Function(Uint8List bytes) saveFile,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'vocabulary_trainer_database_export_',
  );
  try {
    final path = '${directory.path}/${DatabaseBackupService.databaseFileName}';
    await backupService.exportDatabase(destinationPath: path);
    final info = await backupService.validateDatabase(path);
    final bytes = await File(path).readAsBytes();
    final destination = await saveFile(bytes);
    return destination == null ? null : info;
  } finally {
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // Cleanup failure must not turn a completed save into an export failure.
    }
  }
}
