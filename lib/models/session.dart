/// A recording/processing session — shared across workspaces.
///
/// In Healthcare workspace: represents a clinical encounter.
/// In Legal workspace: represents an evidence review session.
class Session {
  final String id;
  final String workspaceId; // 'healthcare' or 'legal'
  final String userId;
  final String organizationId;
  final DateTime startTime;
  final DateTime? endTime;
  final SessionStatus status;

  // Only the structured / redacted output syncs to cloud
  final String? structuredOutput;

  // Metadata
  final String? title;
  final Map<String, dynamic>? metadata;

  Session({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.organizationId,
    required this.startTime,
    this.endTime,
    this.status = SessionStatus.recording,
    this.structuredOutput,
    this.title,
    this.metadata,
  });

  Duration? get duration => endTime?.difference(startTime);

  Map<String, dynamic> toFirestore() {
    // CRITICAL: raw transcript is NEVER included here.
    // Only the redacted structured output goes to Firestore.
    return {
      'id': id,
      'workspaceId': workspaceId,
      'userId': userId,
      'organizationId': organizationId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status.name,
      'structuredOutput': structuredOutput,
      'title': title,
      'metadata': metadata,
    };
  }

  factory Session.fromFirestore(Map<String, dynamic> data) {
    return Session(
      id: data['id'] as String,
      workspaceId: data['workspaceId'] as String,
      userId: data['userId'] as String,
      organizationId: data['organizationId'] as String,
      startTime: DateTime.parse(data['startTime'] as String),
      endTime: data['endTime'] != null
          ? DateTime.parse(data['endTime'] as String)
          : null,
      status: SessionStatus.values.byName(data['status'] as String),
      structuredOutput: data['structuredOutput'] as String?,
      title: data['title'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }
}

enum SessionStatus {
  recording,
  processing,
  complete,
  error,
}
