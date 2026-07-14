import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';

/// Right-side panel that displays and edits `kind: "editable"` documents.
///
/// The parent owns the [documents] map and applies `text_diff` ops via
/// [TextDocument.applyOps]. This widget owns one [TextEditingController] per
/// document and syncs controllers whenever the server increments a version.
class DocumentEditorPanel extends StatefulWidget {
  final Map<String, TextDocument> documents;
  final String? activeFileId;
  final void Function(String fileId) onSelectDocument;
  final void Function(String fileId) onClose;
  /// Called on unfocus when the user has edited the document. The parent
  /// should send a `document_edit` frame and advance the local doc version.
  /// [newText] is the full committed text so the parent can call resetFromResync.
  final void Function(String fileId, String diff, String newText) onUserEdit;
  /// Pending AI-proposed diffs awaiting user accept/reject. Keyed by file_id.
  final Map<String, String> pendingProposals;
  final void Function(String fileId) onAcceptProposal;
  final void Function(String fileId) onRejectProposal;

  const DocumentEditorPanel({
    super.key,
    required this.documents,
    required this.activeFileId,
    required this.onSelectDocument,
    required this.onClose,
    required this.onUserEdit,
    required this.pendingProposals,
    required this.onAcceptProposal,
    required this.onRejectProposal,
  });

  @override
  State<DocumentEditorPanel> createState() => _DocumentEditorPanelState();
}

class _DocumentEditorPanelState extends State<DocumentEditorPanel> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, int> _syncedVersions = {};
  // Content at the time of the last server sync — used as the diff base.
  final Map<String, String> _lastSyncedContent = {};

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(DocumentEditorPanel old) {
    super.didUpdateWidget(old);
    _syncControllers();
  }

  void _syncControllers() {
    for (final entry in widget.documents.entries) {
      final id = entry.key;
      final doc = entry.value;
      if (!_controllers.containsKey(id)) {
        _controllers[id] = TextEditingController(text: doc.content);
        _syncedVersions[id] = doc.version;
        _lastSyncedContent[id] = doc.content;
        final node = FocusNode();
        _focusNodes[id] = node;
        node.addListener(() {
          if (!node.hasFocus) _onUnfocus(id);
        });
      } else if (_syncedVersions[id] != doc.version) {
        // Server applied a diff — update the controller, preserving the cursor
        // as best we can.
        final c = _controllers[id]!;
        final newText = doc.content;
        final offset = c.selection.baseOffset.clamp(0, newText.length);
        c.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: offset),
        );
        _syncedVersions[id] = doc.version;
        _lastSyncedContent[id] = newText;
      }
    }
    // Dispose controllers and focus nodes for documents that were closed.
    final stale = _controllers.keys
        .where((k) => !widget.documents.containsKey(k))
        .toList();
    for (final k in stale) {
      _controllers.remove(k)?.dispose();
      _focusNodes.remove(k)?.dispose();
      _syncedVersions.remove(k);
      _lastSyncedContent.remove(k);
    }
  }

  void _onUnfocus(String id) {
    final base = _lastSyncedContent[id] ?? '';
    final current = _controllers[id]?.text ?? '';
    final doc = widget.documents[id];
    if (doc == null) return;
    final diff = TextDocument.generateDiff(doc.filename, base, current);
    if (diff.isNotEmpty) {
      widget.onUserEdit(id, diff, current);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final docs = widget.documents;
    final activeId = widget.activeFileId;
    final activeDoc = activeId != null ? docs[activeId] : null;
    final activeController = activeId != null ? _controllers[activeId] : null;
    final pendingDiff =
        activeId != null ? widget.pendingProposals[activeId] : null;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tab bar (only when more than one document is open) ──────────
          if (docs.length > 1)
            Container(
              height: 36,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: docs.entries.map((e) {
                  final isActive = e.key == activeId;
                  return _Tab(
                    doc: e.value,
                    isActive: isActive,
                    onTap: () => widget.onSelectDocument(e.key),
                    onClose: () => widget.onClose(e.key),
                  );
                }).toList(),
              ),
            ),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeDoc?.filename ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (activeDoc != null && activeDoc.version > 0)
                  _VersionBadge(version: activeDoc.version),
                if (docs.length == 1 && activeId != null)
                  _CloseButton(onPressed: () => widget.onClose(activeId)),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // ── AI proposal banner ───────────────────────────────────────────
          if (pendingDiff != null && activeId != null)
            _ProposalBanner(
              diff: pendingDiff,
              onAccept: () => widget.onAcceptProposal(activeId),
              onReject: () => widget.onRejectProposal(activeId),
            ),

          // ── Editor body ─────────────────────────────────────────────────
          Expanded(
            child: activeController == null
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: activeController,
                      focusNode: activeId != null ? _focusNodes[activeId] : null,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration.collapsed(hintText: ''),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.55,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final TextDocument doc;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _Tab({
    required this.doc,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                doc.filename,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onClose,
              child: Icon(
                Icons.close,
                size: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  final int version;
  const _VersionBadge({required this.version});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'v$version',
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(4),
      icon: Icon(
        Icons.close,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: onPressed,
    );
  }
}

class _ProposalBanner extends StatelessWidget {
  final String diff;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ProposalBanner({
    required this.diff,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = diff.split('\n');

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              children: [
                Icon(
                  Icons.auto_fix_high_rounded,
                  size: 15,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI suggested changes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onReject,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ),
          // ── Diff view ──────────────────────────────────────────────────
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            color: theme.colorScheme.surfaceContainerLowest,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final line in lines) _DiffLine(line: line),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffLine extends StatelessWidget {
  final String line;
  const _DiffLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color? bg;
    final Color textColor;

    if (line.startsWith('---') || line.startsWith('+++')) {
      bg = null;
      textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    } else if (line.startsWith('-')) {
      bg = isDark
          ? const Color(0x33F44336)
          : const Color(0x1FF44336); // red tint
      textColor = isDark ? const Color(0xFFEF9A9A) : const Color(0xFFB71C1C);
    } else if (line.startsWith('+')) {
      bg = isDark
          ? const Color(0x334CAF50)
          : const Color(0x1F4CAF50); // green tint
      textColor = isDark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20);
    } else if (line.startsWith('@@')) {
      bg = isDark
          ? const Color(0x221E88E5)
          : const Color(0x111E88E5); // blue tint
      textColor = isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0);
    } else {
      bg = null;
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    return Container(
      color: bg,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Text(
        line,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.55,
          color: textColor,
        ),
      ),
    );
  }
}
