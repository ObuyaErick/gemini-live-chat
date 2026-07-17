/// A file produced by the server (chart JSON, editable document, image, or any
/// other download) attached to a message. Records arrive on `final.attachments`,
/// on history model entries, and on `GET /threads/{id}` message rows — always
/// with a freshly resolved, short-lived [url].
class Attachment {
  final String fileId;
  final String filename;
  final String mimeType;

  /// Semantic kind from the server. One of: `plotly`, `editable`, `image`,
  /// `file`. Null on older rows — fall back to mime-type inference in that case.
  final String? kind;
  final String url;
  final int? sizeBytes;

  const Attachment({
    required this.fileId,
    required this.filename,
    required this.mimeType,
    this.kind,
    required this.url,
    this.sizeBytes,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      fileId: (json['file_id'] as String?) ?? '',
      filename: (json['filename'] as String?) ?? 'attachment',
      mimeType: (json['mime_type'] as String?) ?? 'application/octet-stream',
      kind: json['kind'] as String?,
      url: (json['url'] as String?) ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
    );
  }

  bool get isPlotlyJson =>
      kind == 'plotly' || (kind == null && mimeType == 'application/json');
  bool get isEditable => kind == 'editable';
  bool get isImage =>
      kind == 'image' || (kind == null && mimeType.startsWith('image/'));
}
