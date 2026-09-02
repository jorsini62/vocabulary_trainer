import 'package:flutter/material.dart';

class ImportFileSelector extends StatelessWidget {
  final String? selectedFileName;
  final VoidCallback onChooseFile;
  final VoidCallback onClear;

  const ImportFileSelector({
    super.key,
    required this.selectedFileName,
    required this.onChooseFile,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Import File',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: onChooseFile,
            child: const Text('Choose File...'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180, maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  selectedFileName ?? 'No file selected',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selectedFileName == null
                        ? Colors.grey
                        : Colors.black,
                  ),
                ),
              ),
            ),
            if (selectedFileName != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Clear selected file',
                icon: const Icon(Icons.close),
                onPressed: onClear,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Supported import formats:\n'
          '• UTF-8 tab-delimited text (.txt)\n'
          '• UTF-16 Unicode text (.txt, Excel "Unicode Text")\n\n'
          'One vocabulary item per line.\n'
          'Each line must contain exactly one source expression and one target expression, separated by a tab.',
          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.35),
        ),
      ],
    );
  }
}
