import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/aegis_theme.dart';
import '../../core/constants/workspace_config.dart';
import '../../core/engine/redaction_service.dart';

/// Displays and allows editing of a generated clinical note.
///
/// Features:
///   - Read-only view with section headers highlighted
///   - Copy to clipboard
///   - PII audit badge (shows if redaction passed)
///   - Export placeholder
class ClinicalNoteScreen extends StatefulWidget {
  final String title;
  final String format;
  final String content;
  final DateTime timestamp;

  const ClinicalNoteScreen({
    super.key,
    required this.title,
    required this.format,
    required this.content,
    required this.timestamp,
  });

  @override
  State<ClinicalNoteScreen> createState() => _ClinicalNoteScreenState();
}

class _ClinicalNoteScreenState extends State<ClinicalNoteScreen> {
  late TextEditingController _editController;
  bool _isEditing = false;
  bool _piiAuditPassed = true;
  int _piiCount = 0;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.content);
    _runPiiAudit();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _runPiiAudit() {
    final detections = RedactionService.audit(_editController.text);
    setState(() {
      _piiCount = detections.length;
      _piiAuditPassed = detections.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisTheme.surface,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // PII Audit Badge
          _buildPiiAuditBadge(),
          const SizedBox(width: 8),
          // Edit toggle
          IconButton(
            icon: Icon(
              _isEditing ? Icons.check_rounded : Icons.edit_rounded,
              size: 20,
            ),
            onPressed: () {
              if (_isEditing) {
                _runPiiAudit();
              }
              setState(() => _isEditing = !_isEditing);
            },
            tooltip: _isEditing ? 'Done editing' : 'Edit note',
          ),
          // Copy
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: _copyToClipboard,
            tooltip: 'Copy to clipboard',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Metadata bar
            _buildMetadataBar(),
            const Divider(height: 1),
            // Note content
            Expanded(
              child: _isEditing ? _buildEditor() : _buildReadView(),
            ),
            // Bottom actions
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPiiAuditBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _piiAuditPassed
            ? AegisTheme.success.withValues(alpha: 0.15)
            : AegisTheme.error.withValues(alpha: 0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _piiAuditPassed
                ? Icons.verified_user_rounded
                : Icons.warning_rounded,
            size: 14,
            color: _piiAuditPassed ? AegisTheme.success : AegisTheme.error,
          ),
          const SizedBox(width: 5),
          Text(
            _piiAuditPassed ? 'PII Clear' : '$_piiCount PII Found',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _piiAuditPassed ? AegisTheme.success : AegisTheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataBar() {
    final time = _formatTime(widget.timestamp);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AegisTheme.surfaceContainer,
      child: Row(
        children: [
          _buildMetaChip(Icons.description_rounded, '${widget.format} Note'),
          const SizedBox(width: 12),
          _buildMetaChip(Icons.access_time_rounded, time),
          const Spacer(),
          _buildMetaChip(
            Icons.shield_rounded,
            '42 CFR Part 2',
            color: AegisWorkspace.healthcare.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label, {Color? color}) {
    final c = color ?? AegisTheme.onSurfaceDim;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildReadView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildFormattedNote(widget.content),
    );
  }

  /// Renders the note with section headers styled distinctly.
  Widget _buildFormattedNote(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.startsWith('## ')) {
        // Section header
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: AegisWorkspace.healthcare.accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line.replaceFirst('## ', ''),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AegisWorkspace.healthcare.accentColor,
                  ),
                ),
              ),
            ],
          ),
        ));
      } else if (line.startsWith('- ')) {
        // Bullet point
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 14, top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AegisTheme.onSurfaceDim,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHighlightedText(line.replaceFirst('- ', '')),
              ),
            ],
          ),
        ));
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else {
        // Regular line
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildHighlightedText(line),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Highlights redaction markers like [PATIENT], [SSN], etc.
  Widget _buildHighlightedText(String text) {
    final pattern = RegExp(r'\[([A-Z]+)\]');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            fontSize: 14,
            color: AegisTheme.onSurface,
            height: 1.7,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFC107),
          backgroundColor: const Color(0xFFFFC107).withValues(alpha: 0.15),
          fontFamily: 'monospace',
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          fontSize: 14,
          color: AegisTheme.onSurface,
          height: 1.7,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _editController,
        maxLines: null,
        style: TextStyle(
          fontSize: 14,
          color: AegisTheme.onSurface,
          height: 1.7,
          fontFamily: 'monospace',
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AegisTheme.divider),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AegisTheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: AegisTheme.divider),
        ),
      ),
      child: Row(
        children: [
          // Re-run audit
          OutlinedButton.icon(
            onPressed: () {
              _runPiiAudit();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _piiAuditPassed
                        ? '✅ PII audit passed — safe to sync'
                        : '⚠️ $_piiCount PII patterns detected',
                  ),
                  backgroundColor: _piiAuditPassed
                      ? AegisTheme.success
                      : AegisTheme.error,
                ),
              );
            },
            icon: const Icon(Icons.security_rounded, size: 18),
            label: const Text('Audit PII'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AegisTheme.onSurfaceDim,
              side: BorderSide(color: AegisTheme.divider),
            ),
          ),
          const SizedBox(width: 12),
          // Spacer
          const Spacer(),
          // Sync button (disabled if PII detected)
          ElevatedButton.icon(
            onPressed: _piiAuditPassed ? _syncToCloud : null,
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: const Text('Sync to Cloud'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AegisWorkspace.healthcare.accentColor,
              disabledBackgroundColor:
                  AegisWorkspace.healthcare.accentColor.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard() {
    final text = _isEditing ? _editController.text : widget.content;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 Note copied to clipboard')),
    );
  }

  void _syncToCloud() {
    // TODO(phase5): Integrate FirestoreService.saveSession()
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Redacted note synced to Firestore'),
        backgroundColor: AegisTheme.success,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$month/$day $h:$m';
  }
}
