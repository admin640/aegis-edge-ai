import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Audio capture service for session recording.
///
/// Handles microphone input for both Healthcare (clinical sessions)
/// and Legal (evidence review dictation) workspaces.
///
/// PRIVACY: All audio stays LOCAL. Never transmitted to cloud.
class AudioService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _isPaused = false;
  Duration _elapsed = Duration.zero;
  String? _currentFilePath;
  String? _error;
  Timer? _durationTimer;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  Duration get elapsed => _elapsed;
  String? get currentFilePath => _currentFilePath;
  String? get error => _error;

  /// Check if recording is available on this device.
  Future<bool> isAvailable() async {
    return await _recorder.hasPermission();
  }

  /// Start recording a new session.
  /// Returns the file path where audio will be saved.
  Future<String> startRecording({String? sessionId}) async {
    try {
      _error = null;

      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      // Create file path in app's local documents
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/aegis/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final fileName = sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
      _currentFilePath = '${audioDir.path}/$fileName.m4a';

      // Configure recording
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      );

      await _recorder.start(config, path: _currentFilePath!);

      _isRecording = true;
      _isPaused = false;
      _elapsed = Duration.zero;
      _startDurationTimer();
      notifyListeners();

      return _currentFilePath!;
    } catch (e) {
      _error = 'Failed to start recording: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Pause the current recording.
  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;

    await _recorder.pause();
    _isPaused = true;
    _durationTimer?.cancel();
    notifyListeners();
  }

  /// Resume a paused recording.
  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;

    await _recorder.resume();
    _isPaused = false;
    _startDurationTimer();
    notifyListeners();
  }

  /// Stop recording and return the file path.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;
    _isPaused = false;
    _durationTimer?.cancel();
    notifyListeners();

    return path;
  }

  /// Delete the recorded audio file (for cleanup).
  Future<void> deleteRecording(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get the amplitude of the current recording (for waveform visualization).
  Future<double> getAmplitude() async {
    if (!_isRecording || _isPaused) return 0.0;
    final amplitude = await _recorder.getAmplitude();
    // Normalize to 0.0 - 1.0 range
    // Current amplitude is in dBFS (negative values, 0 = max)
    final normalized = (amplitude.current + 60) / 60;
    return normalized.clamp(0.0, 1.0);
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
