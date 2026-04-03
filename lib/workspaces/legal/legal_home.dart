import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/aegis_theme.dart';
import '../../core/constants/workspace_config.dart';
import '../../core/engine/gemma_service.dart';
import '../../core/engine/redaction_service.dart';
import '../legal/prompts/legal_prompts.dart';

/// Legal workspace home — multi-turn evidence analysis + transcript review.
///
/// Flow: Select Analysis Mode → Paste Evidence → Chat with AI → Export Report
class LegalHome extends StatefulWidget {
  final VoidCallback onExit;

  const LegalHome({super.key, required this.onExit});

  @override
  State<LegalHome> createState() => _LegalHomeState();
}

class _LegalHomeState extends State<LegalHome> with TickerProviderStateMixin {
  // Chat state
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isStreaming = false;

  // Analysis mode selection
  String _selectedMode = 'Evidence Analysis';
  final Map<String, String> _modePrompts = {
    'Evidence Analysis': LegalPrompts.evidenceAnalysis,
    'Transcript Summary': LegalPrompts.transcriptSummary,
    'Discovery Review': LegalPrompts.discoveryReview,
  };

  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    // Add welcome message
    _messages.add(_ChatMessage(
      text: 'Welcome to Aegis Discovery Desk.\n\n'
          'Paste a transcript, body-cam footage transcript, or discovery document below. '
          'All analysis is performed 100% on-device — nothing leaves this machine.\n\n'
          'Select an analysis mode above to begin.',
      isUser: false,
      timestamp: DateTime.now(),
    ));

    // Check model status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GemmaService>().checkModelInstalled();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisTheme.surface,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildModeSelector(),
            _buildModelBar(),
            const Divider(height: 1),
            // Chat messages
            Expanded(child: _buildChatArea()),
            // Input bar
            _buildInputBar(),
          ],
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
          Icon(AegisWorkspace.legal.icon,
              size: 22, color: AegisWorkspace.legal.accentColor),
          const SizedBox(width: 10),
          const Text('Discovery Desk'),
        ],
      ),
      actions: [
        // Export button
        IconButton(
          icon: const Icon(Icons.download_rounded, size: 20),
          onPressed: _messages.length > 1 ? _exportReport : null,
          tooltip: 'Export analysis report',
        ),
        // Clear chat
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          onPressed: _messages.length > 1 ? _clearChat : null,
          tooltip: 'Clear conversation',
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AegisWorkspace.legal.accentColor.withValues(alpha: 0.15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded,
                  size: 14, color: AegisWorkspace.legal.accentColor),
              const SizedBox(width: 6),
              Text(
                'PRIVILEGED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AegisWorkspace.legal.accentColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Mode Selector ──

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AegisTheme.surfaceContainer,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _modePrompts.keys.map((mode) {
            final isSelected = _selectedMode == mode;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedMode = mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isSelected
                        ? AegisWorkspace.legal.accentColor
                        : AegisTheme.surfaceContainerHigh,
                    border: Border.all(
                      color: isSelected
                          ? AegisWorkspace.legal.accentColor
                          : AegisTheme.divider,
                    ),
                  ),
                  child: Text(
                    mode,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? Colors.white : AegisTheme.onSurfaceDim,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Model Status Bar ──

  Widget _buildModelBar() {
    return Consumer<GemmaService>(
      builder: (context, gemma, _) {
        final isReady = gemma.isModelLoaded;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AegisTheme.surfaceContainer,
          child: Row(
            children: [
              Icon(
                isReady ? Icons.check_circle_rounded : Icons.memory_rounded,
                size: 14,
                color: isReady ? AegisTheme.success : AegisTheme.onSurfaceDim,
              ),
              const SizedBox(width: 6),
              Text(
                isReady ? 'Gemma 4 E4B — Ready' : 'Model not loaded',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isReady ? AegisTheme.onSurfaceDim : AegisTheme.error,
                ),
              ),
              const Spacer(),
              if (!gemma.isModelInstalled)
                TextButton(
                  onPressed: () => gemma.installModel(),
                  child: Text('Download',
                      style: TextStyle(
                          fontSize: 12,
                          color: AegisWorkspace.legal.accentColor)),
                )
              else if (!isReady)
                TextButton(
                  onPressed: () => gemma.loadModel(),
                  child: Text('Load Model',
                      style: TextStyle(
                          fontSize: 12,
                          color: AegisWorkspace.legal.accentColor)),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Chat Area ──

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageBubble(msg, index);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, int index) {
    final accent = AegisWorkspace.legal.accentColor;

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment:
              msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.gavel_rounded, size: 16, color: accent),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                    bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                  ),
                  color: msg.isUser
                      ? accent.withValues(alpha: 0.2)
                      : AegisTheme.surfaceContainer,
                  border: Border.all(
                    color: msg.isUser
                        ? accent.withValues(alpha: 0.3)
                        : AegisTheme.divider,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormattedResponse(msg.text, msg.isUser),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(msg.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: AegisTheme.onSurfaceDim.withValues(alpha: 0.6),
                          ),
                        ),
                        if (!msg.isUser) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _copyMessage(msg.text),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 12,
                              color:
                                  AegisTheme.onSurfaceDim.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (msg.isUser) ...[
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AegisTheme.surfaceContainerHigh,
                ),
                child: Icon(Icons.person_rounded,
                    size: 16, color: AegisTheme.onSurfaceDim),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Render response with severity-colored markers and section headers.
  Widget _buildFormattedResponse(String text, bool isUser) {
    if (isUser) {
      return SelectableText(
        text,
        style: TextStyle(
          fontSize: 14,
          color: AegisTheme.onSurface,
          height: 1.6,
        ),
      );
    }

    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            line.replaceFirst('## ', ''),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AegisWorkspace.legal.accentColor,
            ),
          ),
        ));
      } else if (line.startsWith('🔴')) {
        widgets.add(_buildSeverityLine(line, const Color(0xFFFF6B6B)));
      } else if (line.startsWith('🟡')) {
        widgets.add(_buildSeverityLine(line, const Color(0xFFFFC107)));
      } else if (line.startsWith('🟢')) {
        widgets.add(_buildSeverityLine(line, AegisTheme.success));
      } else if (line.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AegisTheme.onSurfaceDim,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  line.replaceFirst('- ', ''),
                  style: TextStyle(
                    fontSize: 13,
                    color: AegisTheme.onSurface,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ));
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 6));
      } else {
        widgets.add(SelectableText(
          line,
          style: TextStyle(
            fontSize: 13,
            color: AegisTheme.onSurface,
            height: 1.6,
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildSeverityLine(String line, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: SelectableText(
        line,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
          height: 1.5,
        ),
      ),
    );
  }

  // ── Input Bar ──

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AegisTheme.surfaceContainer,
        border: Border(top: BorderSide(color: AegisTheme.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: 5,
              minLines: 1,
              style: TextStyle(
                fontSize: 14,
                color: AegisTheme.onSurface,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Paste transcript or ask a follow-up question…',
                hintStyle: TextStyle(
                    color: AegisTheme.onSurfaceDim.withValues(alpha: 0.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: AegisTheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Consumer<GemmaService>(
            builder: (context, gemma, _) {
              final canSend = gemma.isModelLoaded &&
                  _inputController.text.trim().isNotEmpty &&
                  !_isStreaming;

              return GestureDetector(
                onTap: canSend ? _sendMessage : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canSend
                        ? AegisWorkspace.legal.accentColor
                        : AegisTheme.surfaceContainerHigh,
                  ),
                  child: _isStreaming
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: canSend
                              ? Colors.white
                              : AegisTheme.onSurfaceDim,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Actions ──

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final gemma = context.read<GemmaService>();
    if (!gemma.isModelLoaded) return;

    // Add user message
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isStreaming = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final systemPrompt = _modePrompts[_selectedMode]!;
      final output = await gemma.process(
        systemPrompt: systemPrompt,
        userInput: text,
      );

      // Apply legal-specific PII redaction
      final redacted = RedactionService.redactLegal(output);

      setState(() {
        _messages.add(_ChatMessage(
          text: redacted,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isStreaming = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: '⚠️ Analysis failed: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isStreaming = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 Copied to clipboard')),
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(
        text: 'Conversation cleared. All data remains on-device only.',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _exportReport() {
    // Compose a report from all AI responses
    final buffer = StringBuffer();
    buffer.writeln('AEGIS LEGAL ANALYSIS REPORT');
    buffer.writeln('=' * 40);
    buffer.writeln('Mode: $_selectedMode');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Status: ATTORNEY-CLIENT PRIVILEGED');
    buffer.writeln('=' * 40);
    buffer.writeln();

    for (final msg in _messages) {
      if (msg.isUser) {
        buffer.writeln('[INPUT] ${_formatTime(msg.timestamp)}');
        buffer.writeln(msg.text);
      } else {
        buffer.writeln('[ANALYSIS] ${_formatTime(msg.timestamp)}');
        buffer.writeln(msg.text);
      }
      buffer.writeln();
      buffer.writeln('-' * 40);
      buffer.writeln();
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('📋 Full report copied to clipboard'),
        backgroundColor: AegisWorkspace.legal.accentColor,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
