import 'database_manager.dart';
import 'configuration_repository.dart';

class SQLiteConfigurationRepository
    implements ConfigurationRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;
}