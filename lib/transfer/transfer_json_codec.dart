import 'dart:convert';

import '../domain/learning_state.dart';
import 'transfer_models.dart';

class TransferFormatException implements Exception {
  final String message;

  const TransferFormatException(this.message);

  @override
  String toString() => 'TransferFormatException: $message';
}

class TransferJsonCodec {
  static const String formatIdentifier = 'vocabulary-trainer-transfer';
  static const int currentFormatVersion = 1;
  static const String studySetTransferType = 'studySet';
  static const String everythingTransferType = 'everything';

  String encodeStudySet(TransferStudySetPackage package) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': formatIdentifier,
      'version': package.formatVersion,
      'transferType': package.transferType,
      'exportedAt': package.exportedAt.toUtc().toIso8601String(),
      'languagePair': _languagePairToJson(package.languagePair),
      'sourceStudySetName': package.sourceStudySetName,
      'vocabularyItems': package.vocabularyItems
          .map(_vocabularyItemToJson)
          .toList(),
    });
  }

  String encodeEverything(TransferEverythingPackage package) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': formatIdentifier,
      'version': package.formatVersion,
      'transferType': package.transferType,
      'exportedAt': package.exportedAt.toUtc().toIso8601String(),
      'languagePairs': package.languagePairs
          .map(_languagePairToJson)
          .toList(),
      'studySets': package.studySets.map(_studySetToJson).toList(),
      'vocabularyItems': package.vocabularyItems
          .map(_vocabularyItemToJson)
          .toList(),
      'memberships': package.memberships.map(_membershipToJson).toList(),
    });
  }

  TransferStudySetPackage decodeStudySet(String json) {
    final root = _decodeRoot(json);
    _requireTransferType(root, studySetTransferType);

    final languagePair = _languagePairFromJson(root['languagePair']);
    final sourceStudySetName = _requireString(
      root['sourceStudySetName'],
      'sourceStudySetName',
    );
    final rawItems = _requireList(root['vocabularyItems'], 'vocabularyItems');

    return TransferStudySetPackage(
      formatVersion: _version(root),
      transferType: studySetTransferType,
      exportedAt: _dateTime(root['exportedAt'], 'exportedAt'),
      languagePair: languagePair,
      sourceStudySetName: sourceStudySetName,
      vocabularyItems: rawItems
          .map(_vocabularyItemFromJson)
          .toList(growable: false),
    );
  }

  TransferEverythingPackage decodeEverything(String json) {
    final root = _decodeRoot(json);
    _requireTransferType(root, everythingTransferType);

    final rawPairs = _requireList(root['languagePairs'], 'languagePairs');
    final rawStudySets = _requireList(root['studySets'], 'studySets');
    final rawItems = _requireList(root['vocabularyItems'], 'vocabularyItems');
    final rawMemberships = _requireList(root['memberships'], 'memberships');

    return TransferEverythingPackage(
      formatVersion: _version(root),
      transferType: everythingTransferType,
      exportedAt: _dateTime(root['exportedAt'], 'exportedAt'),
      languagePairs: rawPairs
          .map(_languagePairFromJson)
          .toList(growable: false),
      studySets: rawStudySets
          .map(_studySetFromJson)
          .toList(growable: false),
      vocabularyItems: rawItems
          .map(_vocabularyItemFromJson)
          .toList(growable: false),
      memberships: rawMemberships
          .map(_membershipFromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> _decodeRoot(String json) {
    dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      throw TransferFormatException('The file is not valid JSON: ${e.message}');
    }

    if (decoded is! Map) {
      throw const TransferFormatException(
        'The transfer document root must be a JSON object.',
      );
    }

    final root = Map<String, dynamic>.from(decoded);
    if (root['format'] != formatIdentifier) {
      throw const TransferFormatException(
        'The file is not a Vocabulary Trainer Transfer file.',
      );
    }

    final version = root['version'];
    if (version is! int || version != currentFormatVersion) {
      throw TransferFormatException(
        'Unsupported Transfer format version: $version.',
      );
    }

    return root;
  }

  int _version(Map<String, dynamic> root) => root['version'] as int;

  void _requireTransferType(Map<String, dynamic> root, String expected) {
    if (root['transferType'] != expected) {
      throw TransferFormatException(
        'Expected transfer type "$expected", found "${root['transferType']}".',
      );
    }
  }

  Map<String, dynamic> _languagePairToJson(TransferLanguagePairData value) => {
        'sourceLanguage': value.sourceLanguage,
        'targetLanguage': value.targetLanguage,
      };

  TransferLanguagePairData _languagePairFromJson(dynamic value) {
    if (value is! Map) {
      throw const TransferFormatException('languagePair must be an object.');
    }
    final map = Map<String, dynamic>.from(value);
    return TransferLanguagePairData(
      sourceLanguage: _requireString(map['sourceLanguage'], 'sourceLanguage'),
      targetLanguage: _requireString(map['targetLanguage'], 'targetLanguage'),
    );
  }

  Map<String, dynamic> _vocabularyItemToJson(
    TransferVocabularyItemData value,
  ) => {
        'languagePair': _languagePairToJson(value.languagePair),
        'sourceExpression': value.sourceExpression,
        'targetExpression': value.targetExpression,
        'learningState': value.learningState.name,
        'learningTimestamp': value.learningTimestamp?.toUtc().toIso8601String(),
      };

  TransferVocabularyItemData _vocabularyItemFromJson(dynamic value) {
    if (value is! Map) {
      throw const TransferFormatException('vocabularyItems entry must be an object.');
    }
    final map = Map<String, dynamic>.from(value);
    final rawState = _requireString(map['learningState'], 'learningState');
    final learningState = LearningState.values.cast<LearningState?>().firstWhere(
      (state) => state?.name == rawState,
      orElse: () => null,
    );
    if (learningState == null) {
      throw TransferFormatException('Unsupported learning state: $rawState.');
    }

    return TransferVocabularyItemData(
      languagePair: _languagePairFromJson(map['languagePair']),
      sourceExpression: _requireString(
        map['sourceExpression'],
        'sourceExpression',
      ),
      targetExpression: _requireString(
        map['targetExpression'],
        'targetExpression',
      ),
      learningState: learningState,
      learningTimestamp: _nullableDateTime(
        map['learningTimestamp'],
        'learningTimestamp',
      ),
    );
  }

  Map<String, dynamic> _studySetToJson(TransferStudySetData value) => {
        'languagePair': _languagePairToJson(value.languagePair),
        'name': value.name,
        'isDefaultStudySet': value.isDefaultStudySet,
        'standardLearningWindowSize': value.standardLearningWindowSize,
        'intenseLearningWindowSize': value.intenseLearningWindowSize,
        'minimumInterval': value.minimumInterval,
      };

  TransferStudySetData _studySetFromJson(dynamic value) {
    if (value is! Map) {
      throw const TransferFormatException('studySets entry must be an object.');
    }
    final map = Map<String, dynamic>.from(value);
    return TransferStudySetData(
      languagePair: _languagePairFromJson(map['languagePair']),
      name: _requireString(map['name'], 'name'),
      isDefaultStudySet: _requireBool(
        map['isDefaultStudySet'],
        'isDefaultStudySet',
      ),
      standardLearningWindowSize: _requirePositiveInt(
        map['standardLearningWindowSize'],
        'standardLearningWindowSize',
      ),
      intenseLearningWindowSize: _requirePositiveInt(
        map['intenseLearningWindowSize'],
        'intenseLearningWindowSize',
      ),
      minimumInterval: _requirePositiveInt(
        map['minimumInterval'],
        'minimumInterval',
      ),
    );
  }

  Map<String, dynamic> _membershipToJson(TransferMembershipData value) => {
        'languagePair': _languagePairToJson(value.languagePair),
        'studySetName': value.studySetName,
        'normalizedSourceExpression': value.normalizedSourceExpression,
      };

  TransferMembershipData _membershipFromJson(dynamic value) {
    if (value is! Map) {
      throw const TransferFormatException('memberships entry must be an object.');
    }
    final map = Map<String, dynamic>.from(value);
    return TransferMembershipData(
      languagePair: _languagePairFromJson(map['languagePair']),
      studySetName: _requireString(map['studySetName'], 'studySetName'),
      normalizedSourceExpression: _requireString(
        map['normalizedSourceExpression'],
        'normalizedSourceExpression',
      ),
    );
  }

  String _requireString(dynamic value, String field) {
    if (value is! String || value.isEmpty) {
      throw TransferFormatException('$field must be a non-empty string.');
    }
    return value;
  }

  bool _requireBool(dynamic value, String field) {
    if (value is! bool) {
      throw TransferFormatException('$field must be a boolean.');
    }
    return value;
  }

  int _requirePositiveInt(dynamic value, String field) {
    if (value is! int || value <= 0) {
      throw TransferFormatException('$field must be a positive integer.');
    }
    return value;
  }

  List<dynamic> _requireList(dynamic value, String field) {
    if (value is! List) {
      throw TransferFormatException('$field must be an array.');
    }
    return value;
  }

  DateTime _dateTime(dynamic value, String field) {
    final parsed = _nullableDateTime(value, field);
    if (parsed == null) {
      throw TransferFormatException('$field must contain a valid date/time.');
    }
    return parsed;
  }

  DateTime? _nullableDateTime(dynamic value, String field) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw TransferFormatException('$field must be null or an ISO date/time string.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw TransferFormatException('$field contains an invalid date/time.');
    }
    return parsed.toLocal();
  }
}
