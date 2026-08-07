import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/ui/core/app_theme.dart';

/// Right-side panel that displays and edits `kind: "editable"` documents.
///
/// The parent owns the [documents] map and applies `text_diff` ops via
/// [TextDocument.applyDiff]. This widget owns one [TextEditingController] per
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

  /// Diffs from agent edits already applied to [documents], shown with an
  /// undo affordance. Keyed by file_id.
  final Map<String, String> pendingProposals;

  /// Dismisses the undo banner — the edit is already applied, so this sends
  /// nothing to the server.
  final void Function(String fileId) onAcceptProposal;

  /// Undoes an already-committed agent edit by restoring `old_value` and
  /// relaying it as a manual `document_edit`.
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
    final pendingDiff = activeId != null
        ? widget.pendingProposals[activeId]
        : null;

    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        border: Border(left: BorderSide(color: t.border)),
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
                      focusNode: activeId != null
                          ? _focusNodes[activeId]
                          : null,
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
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'v$version',
        style: AppTheme.mono(size: 10.5, color: t.text3),
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
    final t = context.tokens;
    final lines = diff.split('\n');
    final adds = lines
        .where((l) => l.startsWith('+') && !l.startsWith('+++'))
        .length;
    final dels = lines
        .where((l) => l.startsWith('-') && !l.startsWith('---'))
        .length;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ─────────────────────────────────────────────────
          Container(
            color: t.accentSoft,
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Icon(Icons.auto_fix_high_rounded, size: 15, color: t.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Agent edited this document  ',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: t.text1,
                          ),
                        ),
                        TextSpan(
                          text: '+$adds / −$dels',
                          style: AppTheme.mono(size: 11, color: t.text2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: t.text2,
                    side: BorderSide(color: t.borderStrong),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Undo', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: t.onAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Keep'),
                ),
              ],
            ),
          ),
          // ── Diff view ──────────────────────────────────────────────────
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            color: t.bg2,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final line in lines) _DiffLine(line: line)],
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
    final t = context.tokens;

    Color? bg;
    Color textColor;
    Border? leftBorder;

    if (line.startsWith('---') || line.startsWith('+++')) {
      bg = null;
      textColor = t.text3;
    } else if (line.startsWith('-')) {
      bg = t.diffDel;
      textColor = t.text2;
      leftBorder = Border(left: BorderSide(color: t.diffDelLine, width: 3));
    } else if (line.startsWith('+')) {
      bg = t.diffAdd;
      textColor = t.text1;
      leftBorder = Border(left: BorderSide(color: t.diffAddLine, width: 3));
    } else if (line.startsWith('@@')) {
      bg = t.accentSoft;
      textColor = t.accent;
    } else {
      bg = null;
      textColor = t.text1;
    }

    return Container(
      decoration: BoxDecoration(color: bg, border: leftBorder),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Text(
        line,
        style: AppTheme.mono(
          size: 11.5,
          weight: FontWeight.w400,
          color: textColor,
        ).copyWith(height: 1.6),
      ),
    );
  }
}
