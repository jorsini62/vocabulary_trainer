import 'dart:convert';
import 'dart:io';
import 'package:utf_convert/utf_convert.dart';

class ParsedVocabularyItem {
  final String sourceExpression;
  final String targetExpression;

  const ParsedVocabularyItem({
    required this.sourceExpression,
    required this.targetExpression,
  });
}

class ParsedImport {
  final List<ParsedVocabularyItem> items;
  final List<String> errors;

  const ParsedImport({required this.items, required this.errors});
}

class ImportParser {
  Future<List<String>> readLines(String filePath) async {
  final file = File(filePath);

  if (!await file.exists()) {
    throw Exception('Import file not found.');
  }

  final bytes = await file.readAsBytes();

  String text;

  // UTF-16 (Excel "Unicode Text")
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
       (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
    text = decodeUtf16(bytes);
  } else {
    // UTF-8
    text = utf8.decode(
      bytes,
      allowMalformed: false,
    );
  }

  return const LineSplitter().convert(text);
}

  ParsedImport parseLines(List<String> lines) {
    final items = <ParsedVocabularyItem>[];
    final errors = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final lineNumber = i + 1;
      final line = lines[i].trim();

      if (line.isEmpty) {
        continue;
      }

      final columns = line.split('\t');

      if (columns.length != 2) {
        errors.add(
          'Line $lineNumber: expected exactly two columns; found ${columns.length}.',
        );
        continue;
      }

      final source = columns[0].trim();
      final target = columns[1].trim();

      if (source.isEmpty || target.isEmpty) {
        errors.add('Line $lineNumber: source or target expression is empty.');
        continue;
      }

      items.add(
        ParsedVocabularyItem(
          sourceExpression: source,
          targetExpression: target,
        ),
      );
    }

    return ParsedImport(items: items, errors: errors);
  }
}
