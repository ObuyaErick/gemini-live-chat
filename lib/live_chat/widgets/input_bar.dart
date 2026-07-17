import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/ui/core/app_theme.dart';

class InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isWaiting;
  final String agentShortName;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final List<LocalFileAttachment> stagedFiles;
  final ValueChanged<LocalFileAttachment> onRemoveStagedFile;
  final bool isInLiveMode;
  final VoidCallback? onToggleLiveMode;

  const InputBar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.isWaiting,
    required this.agentShortName,
    required this.onSend,
    required this.onAttach,
    this.stagedFiles = const [],
    required this.onRemoveStagedFile,
    this.isInLiveMode = false,
    this.onToggleLiveMode,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
        decoration: BoxDecoration(
          color: t.bgApp,
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stagedFiles.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final f in stagedFiles)
                        _StagedChip(
                          filename: f.filename,
                          size: _formatSize(f.sizeBytes),
                          onRemove:
                              enabled ? () => onRemoveStagedFile(f) : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.borderStrong),
                    boxShadow: t.e1,
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _CircleIcon(
                        icon: Icons.add_rounded,
                        onTap: enabled ? onAttach : null,
                        tooltip: 'Attach file',
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: TextField(
                            controller: controller,
                            enabled: enabled,
                            minLines: 1,
                            maxLines: 6,
                            textInputAction: TextInputAction.send,
                            onSubmitted: enabled ? (_) => onSend() : null,
                            cursorColor: t.accent,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: isWaiting
                                  ? '$agentShortName is thinking…'
                                  : 'Ask $agentShortName anything…',
                              hintStyle: TextStyle(color: t.text3),
                            ),
                            style: TextStyle(
                              fontSize: 14.5,
                              color: t.text1,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      _CircleIcon(
                        icon: isInLiveMode
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        onTap: (enabled || isInLiveMode)
                            ? onToggleLiveMode
                            : null,
                        tooltip:
                            isInLiveMode ? 'End voice mode' : 'Enter voice mode',
                        color: isInLiveMode ? t.danger : null,
                      ),
                      const SizedBox(width: 4),
                      _SendButton(
                        isWaiting: isWaiting,
                        onTap: enabled ? onSend : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Center(
                  child: Text(
                    '$agentShortName can make mistakes. Verify consequential actions before confirming.',
                    style: TextStyle(fontSize: 11, color: t.text3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final Color? color;

  const _CircleIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: t.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: t.border),
        ),
        minimumSize: const Size(36, 36),
        fixedSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(
        icon,
        size: 18,
        color: color ?? (enabled ? t.text2 : t.text3),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isWaiting;
  final VoidCallback? onTap;

  const _SendButton({required this.isWaiting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null && !isWaiting;
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: enabled ? t.accent : t.bg3,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Center(
            child: isWaiting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.text3,
                    ),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    size: 18,
                    color: enabled ? t.onAccent : t.text3,
                  ),
          ),
        ),
      ),
    );
  }
}

class _StagedChip extends StatelessWidget {
  final String filename;
  final String size;
  final VoidCallback? onRemove;

  const _StagedChip({
    required this.filename,
    required this.size,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 6, 9, 6),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 16, color: t.text2),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                filename,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: t.text1,
                ),
              ),
              Text(size, style: TextStyle(fontSize: 10.5, color: t.text3)),
            ],
          ),
          const SizedBox(width: 8),
          if (onRemove != null)
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(6),
              child: Icon(Icons.close_rounded, size: 15, color: t.text3),
            ),
        ],
      ),
    );
  }
}
