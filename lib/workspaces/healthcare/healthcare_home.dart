import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/theme/aegis_theme.dart';
import '../../core/constants/workspace_config.dart';
import '../../core/engine/gemma_service.dart';
import '../../core/engine/audio_service.dart';
import '../../core/engine/redaction_service.dart';
// LocalStorageService used by AudioService internally
import '../healthcare/prompts/clinical_prompts.dart';
import 'clinical_note_screen.dart';

/// Healthcare workspace home — session recording + model management.
///
/// Flow: Model Setup → Record Session → AI Generates Clinical Note → Review
class HealthcareHome extends StatefulWidget {
  final VoidCallback onExit;

  const HealthcareHome({super.key, required this.onExit});

  @override
  State<HealthcareHome> createState() => _HealthcareHomeState();
}

class _HealthcareHomeState extends State<HealthcareHome>
    with TickerProviderStateMixin {
  // Recording state
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;

  // Simulated transcript (in production: speech-to-text)
  final TextEditingController _transcriptController = TextEditingController();

  // Note format selection
  String _selectedFormat = 'SOAP';
  final List<String> _formats = ['SOAP', 'DAP', 'BPS'];

  // Session list (local demo sessions)
  final List<_SessionEntry> _recentSessions = [];

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Check model status on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GemmaService>().checkModelInstalled();
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisTheme.surface,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModelStatusCard(),
              const SizedBox(height: 20),
              _buildRecordingCard(),
              const SizedBox(height: 20),
              _buildTranscriptInput(),
              const SizedBox(height: 20),
              _buildFormatSelector(),
              const SizedBox(height: 20),
              _buildGenerateButton(),
              const SizedBox(height: 32),
              _buildRecentSessions(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: widget.onExit,
      ),
      title: Row(
        children: [
          Icon(AegisWorkspace.healthcare.icon,
              size: 22, color: AegisWorkspace.healthcare.accentColor),
          const SizedBox(width: 10),
          const Text('Clinical Scribe'),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AegisTheme.success.withValues(alpha: 0.15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AegisTheme.success,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'AIR-GAPPED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AegisTheme.success,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Model Status Card ──

  Widget _buildModelStatusCard() {
    return Consumer<GemmaService>(
      builder: (context, gemma, _) {
        final isInstalled = gemma.isModelInstalled;
        final isLoaded = gemma.isModelLoaded;
        final error = gemma.error;
        final progress = gemma.downloadProgress;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AegisTheme.surfaceContainer,
            border: Border.all(
              color: isLoaded
                  ? AegisTheme.success.withValues(alpha: 0.4)
                  : error != null
                      ? AegisTheme.error.withValues(alpha: 0.4)
                      : AegisTheme.divider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isLoaded
                        ? Icons.check_circle_rounded
                        : Icons.memory_rounded,
                    color: isLoaded ? AegisTheme.success : AegisTheme.onSurfaceDim,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Gemma 4 E4B — On-Device AI',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AegisTheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  _buildStatusChip(isLoaded, isInstalled),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AegisTheme.error.withValues(alpha: 0.1),
                  ),
                  child: Text(
                    error,
                    style: TextStyle(
                        fontSize: 12, color: AegisTheme.error),
                  ),
                ),
              ],
              if (!isInstalled && progress > 0 && progress < 100) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: AegisTheme.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation(
                        AegisWorkspace.healthcare.accentColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Downloading model... $progress%',
                  style: TextStyle(
                    fontSize: 12,
                    color: AegisTheme.onSurfaceDim,
                  ),
                ),
              ],
              if (!isInstalled && progress == 0) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _installModel(context),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download Model (2.3 GB)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AegisWorkspace.healthcare.accentColor,
                      side: BorderSide(
                          color: AegisWorkspace.healthcare.accentColor
                              .withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ],
              if (isInstalled && !isLoaded) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _loadModel(context),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Load Model into Memory'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(bool isLoaded, bool isInstalled) {
    final label =
        isLoaded ? 'Ready' : (isInstalled ? 'Installed' : 'Not Installed');
    final color = isLoaded
        ? AegisTheme.success
        : (isInstalled
            ? const Color(0xFFFFC107)
            : AegisTheme.onSurfaceDim);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.15),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ── Recording Card ──

  Widget _buildRecordingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AegisTheme.surfaceContainer,
        border: Border.all(
          color: _isRecording
              ? AegisTheme.error.withValues(alpha: 0.5)
              : AegisTheme.divider,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.mic_rounded,
                color: _isRecording
                    ? AegisTheme.error
                    : AegisTheme.onSurfaceDim,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Session Recording',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AegisTheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_isRecording)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AegisTheme.error.withValues(
                          alpha: 0.5 + _pulseController.value * 0.5,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Duration
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w200,
              fontFamily: 'monospace',
              color: _isRecording ? AegisTheme.error : AegisTheme.onSurfaceDim,
            ),
          ),
          const SizedBox(height: 16),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Record/Stop
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? AegisTheme.error
                        : AegisWorkspace.healthcare.accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording
                                ? AegisTheme.error
                                : AegisWorkspace.healthcare.accentColor)
                            .withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              if (_isRecording) ...[
                const SizedBox(width: 20),
                // Pause/Resume
                GestureDetector(
                  onTap: _isPaused ? _resumeRecording : _pauseRecording,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AegisTheme.surfaceContainerHigh,
                    ),
                    child: Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: AegisTheme.onSurface,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording
                ? 'Recording session locally… 🔒'
                : 'Tap to start recording',
            style: TextStyle(
              fontSize: 12,
              color: AegisTheme.onSurfaceDim,
            ),
          ),
        ],
      ),
    );
  }

  // ── Transcript Input ──

  Widget _buildTranscriptInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session Transcript',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AegisTheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Paste or edit the session transcript. In production, this auto-populates from speech-to-text.',
          style: TextStyle(
            fontSize: 12,
            color: AegisTheme.onSurfaceDim,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _transcriptController,
          maxLines: 8,
          style: TextStyle(
            fontSize: 14,
            color: AegisTheme.onSurface,
            height: 1.6,
          ),
          decoration: InputDecoration(
            hintText:
                'e.g., "Patient reports 3 days of sobriety. Reports anxiety as primary trigger..."',
            hintStyle:
                TextStyle(color: AegisTheme.onSurfaceDim.withValues(alpha: 0.5)),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  // ── Note Format Selector ──

  Widget _buildFormatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note Format',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AegisTheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _formats.map((format) {
            final isSelected = _selectedFormat == format;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedFormat = format),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? AegisWorkspace.healthcare.accentColor
                        : AegisTheme.surfaceContainerHigh,
                    border: Border.all(
                      color: isSelected
                          ? AegisWorkspace.healthcare.accentColor
                          : AegisTheme.divider,
                    ),
                  ),
                  child: Text(
                    format,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AegisTheme.onSurfaceDim,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Generate Button ──

  Widget _buildGenerateButton() {
    return Consumer<GemmaService>(
      builder: (context, gemma, _) {
        final canGenerate = gemma.isModelLoaded &&
            _transcriptController.text.trim().isNotEmpty &&
            !gemma.isProcessing;

        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canGenerate ? () => _generateNote(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AegisWorkspace.healthcare.accentColor,
              disabledBackgroundColor:
                  AegisWorkspace.healthcare.accentColor.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: gemma.isProcessing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Generating Clinical Note…'),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text('Generate $_selectedFormat Note'),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // ── Recent Sessions ──

  Widget _buildRecentSessions() {
    if (_recentSessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AegisTheme.surfaceContainer,
          border: Border.all(color: AegisTheme.divider),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.description_outlined,
                  size: 40, color: AegisTheme.onSurfaceDim.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                'No sessions yet',
                style: TextStyle(
                  fontSize: 14,
                  color: AegisTheme.onSurfaceDim,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Record a session and generate your first clinical note.',
                style: TextStyle(
                  fontSize: 12,
                  color: AegisTheme.onSurfaceDim.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Sessions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AegisTheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ..._recentSessions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _openNote(s),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AegisTheme.surfaceContainer,
                    border: Border.all(color: AegisTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AegisWorkspace.healthcare.accentColor
                              .withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          Icons.description_rounded,
                          size: 20,
                          color: AegisWorkspace.healthcare.accentColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AegisTheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${s.format} Note • ${_formatDuration(s.duration)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AegisTheme.onSurfaceDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: AegisTheme.onSurfaceDim),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }

  // ── Actions ──

  Future<void> _installModel(BuildContext context) async {
    final gemma = context.read<GemmaService>();
    try {
      await gemma.installModel();
    } catch (e) {
      // Error is shown via Consumer
    }
  }

  Future<void> _loadModel(BuildContext context) async {
    final gemma = context.read<GemmaService>();
    try {
      await gemma.loadModel();
    } catch (e) {
      // Error is shown via Consumer
    }
  }

  void _startRecording() async {
    final audio = context.read<AudioService>();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      await audio.startRecording(sessionId: timestamp);
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingDuration = Duration.zero;
      });
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isPaused) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        }
      });
    } catch (e) {
      // Handle error
    }
  }

  void _pauseRecording() async {
    await context.read<AudioService>().pauseRecording();
    setState(() => _isPaused = true);
  }

  void _resumeRecording() async {
    await context.read<AudioService>().resumeRecording();
    setState(() => _isPaused = false);
  }

  void _stopRecording() async {
    _durationTimer?.cancel();
    await context.read<AudioService>().stopRecording();
    setState(() => _isRecording = false);
  }

  Future<void> _generateNote(BuildContext context) async {
    final gemma = context.read<GemmaService>();
    final transcript = _transcriptController.text.trim();

    // Select prompt based on format
    String systemPrompt;
    switch (_selectedFormat) {
      case 'SOAP':
        systemPrompt = ClinicalPrompts.soapNote;
        break;
      case 'DAP':
        systemPrompt = ClinicalPrompts.dapNote;
        break;
      case 'BPS':
        systemPrompt = ClinicalPrompts.bpsAssessment;
        break;
      default:
        systemPrompt = ClinicalPrompts.soapNote;
    }

    try {
      final output = await gemma.process(
        systemPrompt: systemPrompt,
        userInput: transcript,
        noteFormat: _selectedFormat,
      );

      // Run PII redaction on the output (healthcare-specific)
      final redacted = RedactionService.redactHealthcare(output);

      // Save to recent sessions
      final entry = _SessionEntry(
        title: 'Session ${_recentSessions.length + 1}',
        format: _selectedFormat,
        duration: _recordingDuration,
        content: redacted,
        timestamp: DateTime.now(),
      );

      setState(() {
        _recentSessions.insert(0, entry);
      });

      // Navigate to note view
      if (context.mounted) {
        _openNote(entry);
      }
    } catch (e) {
      // Error displayed via Consumer
    }
  }

  void _openNote(_SessionEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClinicalNoteScreen(
          title: entry.title,
          format: entry.format,
          content: entry.content,
          timestamp: entry.timestamp,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _SessionEntry {
  final String title;
  final String format;
  final Duration duration;
  final String content;
  final DateTime timestamp;

  _SessionEntry({
    required this.title,
    required this.format,
    required this.duration,
    required this.content,
    required this.timestamp,
  });
}
