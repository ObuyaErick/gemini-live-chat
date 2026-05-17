import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';

class InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isWaiting;
  final String agentShortName;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final List<LocalFileAttachment> stagedFiles;
  final ValueChanged<LocalFileAttachment> onRemoveStagedFile;

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
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        decoration: const BoxDecoration(color: Color(0xFFF6F7FB)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stagedFiles.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final f in stagedFiles)
                    Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(
                        Icons.attach_file_rounded,
                        size: 14,
                      ),
                      label: Text(
                        '${f.filename}  •  ${_formatSize(f.sizeBytes)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      onDeleted: enabled ? () => onRemoveStagedFile(f) : null,
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEDEEF2),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: enabled ? onAttach : null,
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: enabled
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                    tooltip: 'Attach file',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: enabled ? (_) => onSend() : null,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: isWaiting
                            ? '$agentShortName is thinking…'
                            : 'Ask $agentShortName…',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isWaiting
                        ? SizedBox(
                            key: const ValueKey('waiting'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          )
                        : IconButton(
                            key: const ValueKey('send'),
                            onPressed: enabled ? onSend : null,
                            icon: Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: enabled
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFFCBD0D8),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'SHIFT + ENTER FOR NEW LINE • ENTER TO SEND',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.6,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
