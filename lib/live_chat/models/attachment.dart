/// A file produced by the server (chart JSON, editable document, image, or any
/// other download) attached to a message. Records arrive on `final.attachments`,
/// on history model entries, and on `GET /sessions/{id}` message rows — always
/// with a freshly resolved, short-lived [url].
class Attachment {
  final String fileId;
  final String filename;
  final String mimeType;

  /// Semantic kind from the server. One of: `plotly`, `malloy`, `editable`,
  /// `image`, `file`. Null on older rows — fall back to mime-type inference in
  /// that case.
  final String? kind;

  /// Freshly resolved download URL, or empty when the server omitted it
  /// (resolution failed) — see [hasUrl].
  final String url;
  final int? sizeBytes;

  /// Identity of the source record this attachment was materialised from (a
  /// knowledge-base node id, ticket id, …), or null. Distinguishes an
  /// `editable` document backed by a stored node from an unsaved draft.
  final String? resourceId;

  const Attachment({
    required this.fileId,
    required this.filename,
    required this.mimeType,
    this.kind,
    required this.url,
    this.sizeBytes,
    this.resourceId,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      fileId: (json['file_id'] as String?) ?? '',
      filename: (json['filename'] as String?) ?? 'attachment',
      mimeType: (json['mime_type'] as String?) ?? 'application/octet-stream',
      kind: json['kind'] as String?,
      url: (json['url'] as String?) ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      resourceId: json['resource_id'] as String?,
    );
  }

  /// False when URL resolution failed server-side (the field is omitted, not
  /// null) — show the filename without a link rather than fetching nothing.
  bool get hasUrl => url.isNotEmpty;

  bool get isPlotlyJson =>
      kind == 'plotly' ||
      (kind == null && mimeType == 'application/json' && !isMalloyDashboard);

  /// A `malloy.dashboard.v1` envelope. Rendered as its own panel — unlike
  /// charts it carries no ` ```chart ` slot marker in the prose.
  bool get isMalloyDashboard =>
      kind == 'malloy' ||
      (kind == null && mimeType == 'application/vnd.malloy.dashboard+json');

  bool get isEditable => kind == 'editable';
  bool get isImage =>
      kind == 'image' || (kind == null && mimeType.startsWith('image/'));
}
