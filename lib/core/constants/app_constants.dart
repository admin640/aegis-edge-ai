/// App-wide constants for Aegis.
class AppConstants {
  AppConstants._();

  static const String appName = 'Aegis';
  static const String appTagline = 'Air-Gapped Edge AI';
  static const String appDescription =
      'The AI platform for legally prohibited cloud environments.';

  // Gemma 4 Model
  static const String modelName = 'gemma-4-e4b';
  static const String modelStoragePath = 'models/gemma-4-e4b-q4.task';
  static const int modelSizeBytes = 2684354560; // ~2.5 GB

  // Local storage
  static const String localDbName = 'aegis_local';

  // Session config
  static const int maxSessionDurationMinutes = 90;
  static const int audioSampleRate = 16000;
  static const int audioChannels = 1;
}
