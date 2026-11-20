import 'dart:io';

import 'package:flutter/services.dart';

class IosPickedBackupDirectory {
  final String path;
  final String bookmark;

  const IosPickedBackupDirectory({
    required this.path,
    required this.bookmark,
  });
}

/// Dart side of the iOS security-scoped backup-directory bridge.
class IosBackupDirectory {
  static const MethodChannel _channel = MethodChannel(
    'vocabulary_trainer/backup_directory',
  );

  static const String bookmarkPrefix = 'ios_v1:';

  static bool isIosBookmark(String? value) {
    return value != null && value.startsWith(bookmarkPrefix);
  }

  static String encodeBookmark(String base64Bookmark) {
    return '$bookmarkPrefix$base64Bookmark';
  }

  static String decodeBookmark(String stored) {
    if (!stored.startsWith(bookmarkPrefix)) {
      return stored;
    }
    return stored.substring(bookmarkPrefix.length);
  }

  static Future<IosPickedBackupDirectory?> pickDirectory() async {
    if (!Platform.isIOS) {
      throw UnsupportedError('IosBackupDirectory is only available on iOS.');
    }

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'pickDirectory',
    );
    if (result == null) return null;

    final path = result['path'] as String?;
    final bookmark = result['bookmark'] as String?;
    if (path == null || bookmark == null) {
      throw StateError('iOS folder picker returned an incomplete result.');
    }

    return IosPickedBackupDirectory(path: path, bookmark: bookmark);
  }

  static Future<T> withBookmarkAccess<T>({
    required String storedBookmark,
    required Future<T> Function(String directoryPath) action,
  }) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('IosBackupDirectory is only available on iOS.');
    }

    final rawBookmark = decodeBookmark(storedBookmark);
    final started = await _channel.invokeMapMethod<String, dynamic>(
      'startAccess',
      {'bookmark': rawBookmark},
    );

    if (started == null || started['path'] is! String) {
      throw StateError('Could not start access to the iOS backup folder.');
    }

    final path = started['path'] as String;

    try {
      return await action(path);
    } finally {
      try {
        await _channel.invokeMethod<void>('stopAccess');
      } catch (_) {
        // Access cleanup is best-effort.
      }
    }
  }
}
