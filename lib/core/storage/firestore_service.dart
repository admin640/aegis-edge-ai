import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/session.dart';
import '../engine/redaction_service.dart';

/// Cloud Firestore sync service.
///
/// CRITICAL PRIVACY RULE: Only RedactionService-processed structured
/// output is written to Firestore. Raw transcripts and audio NEVER
/// leave the device.
///
/// Data model:
///   organizations/{orgId}/sessions/{sessionId}   — Redacted notes
///   organizations/{orgId}/patients/{patientId}   — Initials only
///   organizations/{orgId}/cases/{caseId}         — Case metadata
class FirestoreService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sync a completed session's structured (redacted) output to Firestore.
  ///
  /// [session] must have `structuredOutput` populated.
  /// The output is run through RedactionService one final time as a safety net.
  Future<void> syncSession({
    required Session session,
    required String organizationId,
    bool isHealthcare = true,
  }) async {
    if (session.structuredOutput == null) {
      throw ArgumentError('Cannot sync session without structured output');
    }

    // SAFETY NET: Run redaction one more time before cloud sync
    final safeOutput = isHealthcare
        ? RedactionService.redactHealthcare(session.structuredOutput!)
        : RedactionService.redactLegal(session.structuredOutput!);

    // Audit for any remaining PII
    final piiAudit = RedactionService.audit(safeOutput);
    if (piiAudit.isNotEmpty) {
      debugPrint('[FirestoreService] WARNING: ${piiAudit.length} potential PII '
          'items detected after redaction. Blocking sync.');
      throw StateError(
        'PII detected in output after redaction. '
        'Sync blocked for safety. Items: $piiAudit',
      );
    }

    // Create the sanitized document
    final doc = session.toFirestore();
    doc['structuredOutput'] = safeOutput; // Override with double-redacted version
    doc['syncedAt'] = FieldValue.serverTimestamp();
    doc['privacyVersion'] = 'v1'; // Track which redaction rules were applied

    await _db
        .collection('organizations')
        .doc(organizationId)
        .collection('sessions')
        .doc(session.id)
        .set(doc, SetOptions(merge: true));
  }

  /// Get all sessions for an organization.
  Stream<List<Session>> getSessions({
    required String organizationId,
    String? workspaceId,
  }) {
    var query = _db
        .collection('organizations')
        .doc(organizationId)
        .collection('sessions')
        .orderBy('startTime', descending: true);

    if (workspaceId != null) {
      query = query.where('workspaceId', isEqualTo: workspaceId);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Session.fromFirestore(doc.data())).toList());
  }

  /// Get a single session by ID.
  Future<Session?> getSession({
    required String organizationId,
    required String sessionId,
  }) async {
    final doc = await _db
        .collection('organizations')
        .doc(organizationId)
        .collection('sessions')
        .doc(sessionId)
        .get();

    if (!doc.exists) return null;
    return Session.fromFirestore(doc.data()!);
  }

  /// Delete a session from Firestore.
  Future<void> deleteSession({
    required String organizationId,
    required String sessionId,
  }) async {
    await _db
        .collection('organizations')
        .doc(organizationId)
        .collection('sessions')
        .doc(sessionId)
        .delete();
  }

  // ── Healthcare-specific ──

  /// Save a patient record (initials only — no PII).
  Future<void> savePatient({
    required String organizationId,
    required String patientId,
    required String initials,
    Map<String, dynamic>? metadata,
  }) async {
    await _db
        .collection('organizations')
        .doc(organizationId)
        .collection('patients')
        .doc(patientId)
        .set({
      'id': patientId,
      'initials': initials,
      'createdAt': FieldValue.serverTimestamp(),
      ...?metadata,
    }, SetOptions(merge: true));
  }

  // ── Legal-specific ──

  /// Save a case file (metadata only — no privileged content).
  Future<void> saveCase({
    required String organizationId,
    required String caseId,
    required String caseReference,
    Map<String, dynamic>? metadata,
  }) async {
    await _db
        .collection('organizations')
        .doc(organizationId)
        .collection('cases')
        .doc(caseId)
        .set({
      'id': caseId,
      'caseReference': caseReference,
      'createdAt': FieldValue.serverTimestamp(),
      ...?metadata,
    }, SetOptions(merge: true));
  }
}
