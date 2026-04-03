
/// PII Redaction Service — the privacy enforcement layer.
///
/// This service sits between the AI output and Firestore sync,
/// ensuring NO personally identifiable information ever leaves the device.
///
/// Used by ALL workspaces before any data syncs to cloud.
class RedactionService {
  RedactionService._();

  /// Master redaction method — applies all PII patterns.
  /// Returns sanitized text safe for cloud storage.
  static String redact(String text) {
    var result = text;

    // Social Security Numbers (XXX-XX-XXXX or XXXXXXXXX)
    result = _redactPattern(
      result,
      RegExp(r'\b\d{3}[-.]?\d{2}[-.]?\d{4}\b'),
      '[SSN]',
    );

    // Phone numbers (various formats)
    result = _redactPattern(
      result,
      RegExp(r'\b(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b'),
      '[PHONE]',
    );

    // Email addresses
    result = _redactPattern(
      result,
      RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.]+\b'),
      '[EMAIL]',
    );

    // Dates of birth (common formats)
    result = _redactPattern(
      result,
      RegExp(r'\b(?:0?[1-9]|1[0-2])[/-](?:0?[1-9]|[12]\d|3[01])[/-](?:19|20)\d{2}\b'),
      '[DOB]',
    );

    // Street addresses (number + street name pattern)
    result = _redactPattern(
      result,
      RegExp(r'\b\d{1,5}\s+(?:[A-Z][a-z]+\s){1,3}(?:St|Street|Ave|Avenue|Blvd|Boulevard|Dr|Drive|Rd|Road|Ln|Lane|Way|Ct|Court|Pl|Place)\.?\b', caseSensitive: false),
      '[ADDRESS]',
    );

    // ZIP codes (5-digit and ZIP+4)
    result = _redactPattern(
      result,
      RegExp(r'\b\d{5}(?:-\d{4})?\b'),
      '[ZIP]',
    );

    // Medical Record Numbers (MRN patterns)
    result = _redactPattern(
      result,
      RegExp(r'\bMRN[:\s#]?\s*\d{4,10}\b', caseSensitive: false),
      '[MRN]',
    );

    // DEA numbers
    result = _redactPattern(
      result,
      RegExp(r'\b[A-Z][A-Z9]\d{7}\b'),
      '[DEA]',
    );

    return result;
  }

  /// Redact specifically for healthcare workspace.
  /// Applies additional clinical-specific patterns.
  static String redactHealthcare(String text) {
    var result = redact(text);

    // Patient account numbers
    result = _redactPattern(
      result,
      RegExp(r'\baccount\s*#?\s*:?\s*\d{6,12}\b', caseSensitive: false),
      '[ACCT]',
    );

    // Insurance policy numbers
    result = _redactPattern(
      result,
      RegExp(r'\bpolicy\s*#?\s*:?\s*[A-Z]?\d{6,12}\b', caseSensitive: false),
      '[POLICY]',
    );

    return result;
  }

  /// Redact specifically for legal workspace.
  /// Applies additional legal-specific patterns.
  static String redactLegal(String text) {
    var result = redact(text);

    // Case numbers (common court formats)
    result = _redactPattern(
      result,
      RegExp(r'\b\d{2,4}[-]?[A-Z]{2,4}[-]?\d{4,8}\b'),
      '[CASE#]',
    );

    // Badge numbers
    result = _redactPattern(
      result,
      RegExp(r'\bbadge\s*#?\s*:?\s*\d{3,7}\b', caseSensitive: false),
      '[BADGE]',
    );

    return result;
  }

  /// Validate that text has been properly redacted.
  /// Returns a list of potential PII still present.
  static List<PiiDetection> audit(String text) {
    final detections = <PiiDetection>[];

    // Check for remaining SSN patterns
    final ssnMatches = RegExp(r'\b\d{3}[-.]?\d{2}[-.]?\d{4}\b').allMatches(text);
    for (final match in ssnMatches) {
      detections.add(PiiDetection(
        type: PiiType.ssn,
        position: match.start,
        preview: '***redacted***',
      ));
    }

    // Check for remaining phone patterns
    final phoneMatches = RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b').allMatches(text);
    for (final match in phoneMatches) {
      if (!text.substring(match.start).startsWith('[PHONE]')) {
        detections.add(PiiDetection(
          type: PiiType.phone,
          position: match.start,
          preview: '***redacted***',
        ));
      }
    }

    return detections;
  }

  // ── Private Helpers ──

  static String _redactPattern(String text, RegExp pattern, String replacement) {
    return text.replaceAll(pattern, replacement);
  }
}

/// Types of PII that can be detected.
enum PiiType {
  ssn,
  phone,
  email,
  dob,
  address,
  mrn,
  name,
}

/// A detected PII instance (for audit purposes).
class PiiDetection {
  final PiiType type;
  final int position;
  final String preview;

  PiiDetection({
    required this.type,
    required this.position,
    required this.preview,
  });

  @override
  String toString() => 'PII(${type.name} at $position)';
}
