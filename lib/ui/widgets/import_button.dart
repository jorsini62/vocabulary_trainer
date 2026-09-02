import 'package:flutter/material.dart';

class ImportButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onPressed;

  const ImportButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: const Text(
          'Import',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}