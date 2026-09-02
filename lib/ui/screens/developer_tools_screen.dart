import 'package:flutter/material.dart';

import '../../repository/database_manager.dart';

class DeveloperToolsScreen extends StatelessWidget {
  const DeveloperToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              print('Delete button pressed');

              await DatabaseManager.instance.deleteDevelopmentDatabase();

              print('Database deleted');

              if (!context.mounted) return;

              await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Database Deleted'),
                  content: const Text(
                    'The development database has been deleted.\n\n'
                    'Restart the application before continuing.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Delete Development Database'),
          ),
        ),
      ),
    );
  }
}
