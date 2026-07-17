/// In-memory representation of an editable text document delivered via a
/// `kind: "editable"` attachment. The server owns the authoritative version
/// number and pushes changes as git unified diffs via `text_diff` events.
class TextDocument {
  final String fileId;
  final String filename;
  final String mimeType;
  List<String> lines;

  /// Server-assigned version number. Only the server increments this.
  int version;

  TextDocument({
    required this.fileId,
    required this.filename,
    required this.mimeType,
    required this.lines,
    this.version = 0,
  });

  String get content => lines.join('\n');

  /// Apply a git unified diff from the server.
  /// Only applied when [fromVersion] matches [version]; returns false otherwise
  /// (version mismatch — wait for an in-flight echo or `document_resync`).
  bool applyDiff(
    String diffText, {
    required int fromVersion,
    required int toVersion,
  }) {
    if (fromVersion != version) return false;
    if (diffText.trim().isNotEmpty) {
      for (final hunk in _parseHunks(diffText).reversed) {
        _applyHunk(hunk);
      }
    }
    version = toVersion;
    return true;
  }

  /// Hard-reset to the server's authoritative copy (sent on conflict via
  /// `document_resync`).
  void resetFromResync(String text, int newVersion) {
    lines = text.split('\n');
    version = newVersion;
  }

  /// Build a full-file replacement git unified diff from [oldText] to
  /// [newText]. Returns an empty string when the content is unchanged.
  static String generateDiff(String filename, String oldText, String newText) {
    if (oldText == newText) return '';
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');
    final buf = StringBuffer()
      ..writeln('diff --git a/$filename b/$filename')
      ..writeln('--- a/$filename')
      ..writeln('+++ b/$filename')
      ..writeln('@@ -1,${oldLines.length} +1,${newLines.length} @@');
    for (final l in oldLines) {
      buf.writeln('-$l');
    }
    for (final l in newLines) {
      buf.writeln('+$l');
    }
    return buf.toString();
  }

  List<_DiffHunk> _parseHunks(String diffText) {
    final hunkRe = RegExp(
      r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',
      multiLine: true,
    );
    final diffLines = diffText.split('\n');
    final hunks = <_DiffHunk>[];
    int i = 0;
    // Skip file-header lines (diff --git, index, ---, +++)
    while (i < diffLines.length && !diffLines[i].startsWith('@@')) {
      i++;
    }
    while (i < diffLines.length) {
      final match = hunkRe.firstMatch(diffLines[i]);
      if (match != null) {
        final oldStart = int.parse(match.group(1)!);
        final oldCount = int.tryParse(match.group(2) ?? '') ?? 1;
        final hunkLines = <String>[];
        i++;
        while (i < diffLines.length && !diffLines[i].startsWith('@@')) {
          hunkLines.add(diffLines[i]);
          i++;
        }
        hunks.add(
          _DiffHunk(oldStart: oldStart, oldCount: oldCount, lines: hunkLines),
        );
      } else {
        i++;
      }
    }
    return hunks;
  }

  void _applyHunk(_DiffHunk hunk) {
    // @@ -0,0 ... means inserting into empty file → startIdx = 0
    final startIdx = hunk.oldStart == 0
        ? 0
        : (hunk.oldStart - 1).clamp(0, lines.length);
    final endIdx = (startIdx + hunk.oldCount).clamp(0, lines.length);
    final newLines = <String>[];
    for (final line in hunk.lines) {
      if (line.startsWith('+')) {
        newLines.add(line.substring(1));
      } else if (line.startsWith(' ')) {
        newLines.add(line.substring(1));
      }
      // '-' lines are removed; '\\ No newline...' markers are skipped
    }
    lines.replaceRange(startIdx, endIdx, newLines);
  }
}

class _DiffHunk {
  final int oldStart;
  final int oldCount;
  final List<String> lines;
  const _DiffHunk({
    required this.oldStart,
    required this.oldCount,
    required this.lines,
  });
}
