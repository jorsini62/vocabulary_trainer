import '../domain/configuration.dart';

abstract class ConfigurationRepository {
  Future<Configuration?> getConfiguration();

  Future<void> saveConfiguration(Configuration configuration);
}