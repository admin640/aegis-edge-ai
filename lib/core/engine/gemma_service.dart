import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../constants/workspace_config.dart';

/// On-device Gemma 4 inference engine powered by flutter_gemma.
///
/// Model: Gemma 4 E4B (Effective 4B) — released April 2, 2026
///   - Built from Gemini 3 research, optimized for edge deployment
///   - 3.65 GB .litertlm file (2.24 GB weights + 0.67 GB embeddings)
///   - Multimodal: text + vision + audio capable
///
/// Model source strategy:
///   1. Firebase Storage (our GCS bucket — fully Google-native)
///   2. HuggingFace litert-community repo (direct URL)
///   3. Bundled in assets for demo/hackathon builds
///
/// Uses the Modern API (^0.12.8) with:
///   - FlutterGemma.installModel() for model management
///   - FlutterGemma.getActiveModel() for inference
///   - Session-based inference for single clinical notes
///   - Chat-based inference for multi-turn legal analysis
///
/// Model format:
///   iOS/iPad: .task (MediaPipe GenAI)
///   macOS:    .litertlm (LiteRT-LM gRPC — required for desktop)
///
/// PRIVACY: 100% on-device. Model downloaded once, runs forever offline.
class GemmaService extends ChangeNotifier {
  // Model state
  bool _isModelInstalled = false;
  bool _isModelLoaded = false;
  bool _isProcessing = false;
  int _downloadProgress = 0;
  String? _error;

  // Inference objects
  InferenceModel? _model;
  AegisWorkspace? _activeWorkspace;

  // ── Public Getters ──

  bool get isModelInstalled => _isModelInstalled;
  bool get isModelLoaded => _isModelLoaded;
  bool get isProcessing => _isProcessing;
  int get downloadProgress => _downloadProgress;
  String? get error => _error;
  AegisWorkspace? get activeWorkspace => _activeWorkspace;

  // ── Model Config ──

  /// Firebase Storage paths for model files.
  /// Source: https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm
  /// One-time admin task: download .litertlm → upload to Firebase Storage
  static const _firebaseModelPathMobile = 'models/gemma-4-E4B-it.task';
  static const _firebaseModelPathDesktop = 'models/gemma-4-E4B-it.litertlm';

  /// Model filenames (used for local installation check).
  static const _modelNameMobile = 'gemma-4-E4B-it.task';
  static const _modelNameDesktop = 'gemma-4-E4B-it.litertlm';

  /// Direct HuggingFace URL for Gemma 4 E4B LiteRT-LM format.
  static const _huggingFaceUrl =
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm';

  /// Enum for model source selection.
  static const ModelSource defaultSource = ModelSource.firebaseStorage;

  // ── Initialization ──

  /// Initialize the flutter_gemma runtime.
  /// Call once at app startup before any model operations.
  static void initializeRuntime() {
    FlutterGemma.initialize(
      maxDownloadRetries: 10,
    );
  }

  /// Set the active workspace context.
  void setWorkspace(AegisWorkspace workspace) {
    _activeWorkspace = workspace;
    notifyListeners();
  }

  /// Check if the model is already installed on device.
  Future<bool> checkModelInstalled() async {
    final modelName = _isDesktop ? _modelNameDesktop : _modelNameMobile;
    _isModelInstalled = await FlutterGemma.isModelInstalled(modelName);
    notifyListeners();
    return _isModelInstalled;
  }

  // ── Model Installation ──

  /// Download and install the Gemma 4 E4B model.
  ///
  /// Supports four sources:
  ///   - [ModelSource.firebaseStorage]: From our Firebase Storage bucket (default)
  ///   - [ModelSource.huggingFace]: Direct from litert-community HuggingFace repo
  ///   - [ModelSource.directUrl]: From any HTTPS URL
  ///   - [ModelSource.asset]: From bundled Flutter assets (demo/hackathon)
  Future<void> installModel({
    ModelSource source = ModelSource.firebaseStorage,
    String? customUrl,
  }) async {
    try {
      _error = null;
      _downloadProgress = 0;
      notifyListeners();

      switch (source) {
        case ModelSource.firebaseStorage:
          await _installFromFirebaseStorage();
          break;
        case ModelSource.huggingFace:
          await _installFromUrl(_huggingFaceUrl);
          break;
        case ModelSource.directUrl:
          if (customUrl == null) {
            throw ArgumentError(
                'customUrl required for ModelSource.directUrl');
          }
          await _installFromUrl(customUrl);
          break;
        case ModelSource.asset:
          await _installFromAsset();
          break;
      }

      _isModelInstalled = true;
      _downloadProgress = 100;
      notifyListeners();
    } catch (e) {
      _error = 'Model install failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Install from our Firebase Storage bucket (Google-native, no third parties).
  Future<void> _installFromFirebaseStorage() async {
    final storagePath =
        _isDesktop ? _firebaseModelPathDesktop : _firebaseModelPathMobile;

    // Get download URL from Firebase Storage (uses our project's GCS bucket)
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    final downloadUrl = await ref.getDownloadURL();

    await _installFromUrl(downloadUrl);
  }

  /// Install from any HTTPS URL.
  /// Works with: Firebase Storage URLs, Kaggle signed URLs, Vertex AI,
  /// or any direct download link.
  Future<void> _installFromUrl(String url) async {
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
    )
        .fromNetwork(url)
        .withProgress((progress) {
      _downloadProgress = progress;
      notifyListeners();
    }).install();
  }

  /// Install from bundled Flutter assets (for demo/hackathon builds).
  /// Place model file in assets/ and add to pubspec.yaml.
  Future<void> _installFromAsset() async {
    final assetName = _isDesktop ? _modelNameDesktop : _modelNameMobile;
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
    )
        .fromAsset(assetName)
        .withProgress((progress) {
      _downloadProgress = progress;
      notifyListeners();
    }).install();
  }

  // ── Model Loading ──

  /// Load the installed model into memory for inference.
  Future<void> loadModel({int maxTokens = 4096}) async {
    try {
      _error = null;
      notifyListeners();

      _model = await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: PreferredBackend.gpu,
      );

      _isModelLoaded = true;
      notifyListeners();
    } catch (e) {
      _error = 'Model load failed: $e';
      _isModelLoaded = false;
      notifyListeners();
      rethrow;
    }
  }

  // ── Inference: Session-based (single request) ──

  /// Process a transcript with a system prompt and return structured output.
  ///
  /// Uses a Session for single-shot inference (ideal for clinical notes).
  /// The session is created and closed per call.
  Future<String> process({
    required String systemPrompt,
    required String userInput,
    String? noteFormat,
  }) async {
    if (_model == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _model!.createSession(
        temperature: 0.3, // Low temp for structured clinical output
        topK: 10,
      );

      // Build the full prompt with system context
      final fullPrompt = _buildPrompt(systemPrompt, userInput, noteFormat);

      await session.addQueryChunk(
        Message.text(text: fullPrompt, isUser: true),
      );

      final response = await session.getResponse();
      await session.close();

      _isProcessing = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isProcessing = false;
      _error = 'Inference failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Stream tokens from the model for real-time UI updates.
  ///
  /// Uses a Session with getResponseAsync() for token-by-token streaming.
  Stream<String> processStream({
    required String systemPrompt,
    required String userInput,
    String? noteFormat,
  }) async* {
    if (_model == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    _isProcessing = true;
    _error = null;
    notifyListeners();

    InferenceModelSession? session;
    try {
      session = await _model!.createSession(
        temperature: 0.3,
        topK: 10,
      );

      final fullPrompt = _buildPrompt(systemPrompt, userInput, noteFormat);
      await session.addQueryChunk(
        Message.text(text: fullPrompt, isUser: true),
      );

      await for (final token in session.getResponseAsync()) {
        yield token;
      }

      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _isProcessing = false;
      _error = 'Streaming failed: $e';
      notifyListeners();
      rethrow;
    } finally {
      await session?.close();
    }
  }

  // ── Inference: Chat-based (multi-turn) ──

  /// Create a persistent chat session for multi-turn conversations.
  /// Useful for Legal workspace (iterative evidence analysis).
  Future<InferenceChat> createChat({
    double temperature = 0.5,
    int topK = 20,
  }) async {
    if (_model == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    return await _model!.createChat(
      temperature: temperature,
      topK: topK,
    );
  }

  // ── Cleanup ──

  /// Unload the model from memory.
  Future<void> unloadModel() async {
    await _model?.close();
    _model = null;
    _isModelLoaded = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _model?.close();
    super.dispose();
  }

  // ── Private Helpers ──

  String _buildPrompt(
      String systemPrompt, String userInput, String? noteFormat) {
    final buffer = StringBuffer();
    buffer.writeln(systemPrompt);
    if (noteFormat != null) {
      buffer.writeln('\nRequested output format: $noteFormat');
    }
    buffer.writeln('\n--- BEGIN TRANSCRIPT ---');
    buffer.writeln(userInput);
    buffer.writeln('--- END TRANSCRIPT ---');
    return buffer.toString();
  }

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Model delivery source options for Gemma 4.
enum ModelSource {
  /// Download from our own Firebase Storage bucket (GCS, fully Google-native).
  /// This is the default and recommended source for production.
  firebaseStorage,

  /// Download directly from HuggingFace litert-community repo.
  /// Source: https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm
  huggingFace,

  /// Download from any direct HTTPS URL.
  /// Use for: signed URLs, Vertex AI Model Registry, GCS direct links.
  directUrl,

  /// Load from bundled Flutter assets (pre-packaged in APK/IPA).
  /// Use for: hackathon demos, offline-first deployments, enterprise pre-loads.
  asset,
}
