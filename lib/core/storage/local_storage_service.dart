import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Local-only storage for sensitive data.
///
/// Raw audio, transcripts, and unredacted content stay here.
/// This data NEVER syncs to cloud.
///
/// Storage structure:
///   {app_docs}/aegis/audio/{sessionId}.m4a    — Raw audio
///   {app_docs}/aegis/transcripts/{sessionId}.txt  — Raw transcript
///   {app_docs}/aegis/models/                  — Cached Gemma model
class LocalStorageService {
  LocalStorageService._();

  static Directory? _baseDir;

  /// Initialize the local storage directories.
  static Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _baseDir = Directory('${appDir.path}/aegis');

    // Create directory structure
    for (final subDir in ['audio', 'transcripts', 'models', 'exports']) {
      final dir = Directory('${_baseDir!.path}/$subDir');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
  }

  /// Get the base directory path.
  static String get basePath {
    if (_baseDir == null) throw StateError('LocalStorageService not initialized');
    return _baseDir!.path;
  }

  static String get audioPath => '$basePath/audio';
  static String get transcriptsPath => '$basePath/transcripts';
  static String get modelsPath => '$basePath/models';
  static String get exportsPath => '$basePath/exports';

  /// Save a raw transcript locally.
  static Future<File> saveTranscript(String sessionId, String content) async {
    final file = File('$transcriptsPath/$sessionId.txt');
    return await file.writeAsString(content);
  }

  /// Read a raw transcript.
  static Future<String?> readTranscript(String sessionId) async {
    final file = File('$transcriptsPath/$sessionId.txt');
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }

  /// Delete a session's local data (audio + transcript).
  static Future<void> deleteSessionData(String sessionId) async {
    final audioFile = File('$audioPath/$sessionId.m4a');
    final transcriptFile = File('$transcriptsPath/$sessionId.txt');

    if (await audioFile.exists()) await audioFile.delete();
    if (await transcriptFile.exists()) await transcriptFile.delete();
  }

  /// Check if the Gemma model is cached locally.
  static Future<bool> isModelCached(String modelFileName) async {
    final file = File('$modelsPath/$modelFileName');
    return await file.exists();
  }

  /// Get total local storage size in bytes.
  static Future<int> getTotalStorageSize() async {
    int totalSize = 0;
    final dir = Directory(basePath);
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    return totalSize;
  }

  /// Format bytes to human-readable string.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Purge all local data (factory reset for the app).
  static Future<void> purgeAll() async {
    final dir = Directory(basePath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await init(); // Recreate empty structure
  }
}
