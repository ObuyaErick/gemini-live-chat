import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // MarkdownStyleSheet passed into ChartMessageContent
import 'package:provider/provider.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/providers/live_chat_provider.dart';
import 'package:webs/live_chat/widgets/attachments_view.dart';
import 'package:webs/live_chat/widgets/avatar.dart';
import 'package:webs/live_chat/widgets/chart_message_content.dart';
import 'package:webs/live_chat/widgets/cursor_blink.dart';
import 'package:webs/ui/core/alerts/app_notification.dart';
import 'package:webs/ui/core/alerts/notification_host.dart';
import 'package:webs/ui/core/app_theme.dart';
import 'package:webs/ui/core/horizontal_layout_breakpoints.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String Function(DateTime) formatTime;

  const MessageBubble({
    super.key,
    required this.message,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isUser = message.role == MessageRole.user;
    final isError = message.status == MessageStatus.error;
    final isStreaming = message.status == MessageStatus.streaming;

    void copyToClipboard() {
      Clipboard.setData(ClipboardData(text: message.content));
      NotificationHost.maybeOf(context)?.pushAlert(
        AppNotification.success(
          'Copied to clipboard',
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Live-mode transcript messages — lighter, italic, "spoken turn" treatment.
    if (message.isTranscript) {
      if (isUser) {
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: t.userBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.userBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_rounded, size: 12, color: t.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: t.text2,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: t.bg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.borderStrong, style: BorderStyle.solid),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.graphic_eq_rounded, size: 14, color: t.text3),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VOICE TRANSCRIPT',
                      style: AppTheme.mono(size: 10, color: t.text3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: t.text2,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    }

    // ── User message ──────────────────────────────────────────────────────
    if (isUser) {
      final hasLocalFiles = message.localAttachments.isNotEmpty;
      final hasHistoryFiles = message.attachments.isNotEmpty;

      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.of(context).size.width *
                (MediaQuery.of(context).size.width < HorizontalBreakpoints().sm
                    ? 0.85
                    : 0.7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasLocalFiles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final f in message.localAttachments)
                        _FileChip(filename: f.filename, mimeType: f.mimeType),
                    ],
                  ),
                ),
              if (hasHistoryFiles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AttachmentsView(attachments: message.attachments),
                ),
              GestureDetector(
                onLongPress: copyToClipboard,
                child: Container(
                  margin: const EdgeInsets.only(top: 6, bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: t.userBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                    border: Border.all(color: t.userBorder),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: t.text1,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 2, bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniIconButton(
                      icon: Icons.copy_rounded,
                      onTap: copyToClipboard,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formatTime(message.createdAt),
                      style: TextStyle(fontSize: 11, color: t.text3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Assistant error ───────────────────────────────────────────────────
    if (isError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(icon: Icons.error_outline, bg: t.dangerSoft, fg: t.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: t.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.dangerSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SYSTEM ERROR · ${formatTime(message.createdAt)}',
                      style: AppTheme.mono(size: 10, color: t.danger),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message.content,
                      style: AppTheme.mono(
                        size: 12.5,
                        weight: FontWeight.w400,
                        color: t.danger,
                      ).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Assistant message ─────────────────────────────────────────────────
    final textColor = t.text1;
    final canCopy = !isStreaming && message.content.isNotEmpty;

    return Consumer<LiveChatProvider>(
      builder: (context, provider, _) {
        final agent = provider.agentById(message.agentId);
        final displayName =
            agent?.agentName ??
            provider.selectedAgent?.agentName ??
            'Assistant';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(
                imageUrl: agent?.agentImageUrl,
                icon: Icons.auto_awesome_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.text1,
                        ),
                      ),
                    ),
                    if (message.imageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            message.imageBytes!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    if (message.content.isNotEmpty)
                      ChartMessageContent(
                        content: message.content,
                        attachments: message.attachments,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            fontSize: 14.5,
                            color: textColor,
                            height: 1.62,
                          ),
                          code: AppTheme.mono(
                            size: 13,
                            weight: FontWeight.w400,
                            color: textColor,
                          ).copyWith(backgroundColor: t.bg3),
                          codeblockPadding: const EdgeInsets.all(14),
                          codeblockDecoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.border),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: t.accentBorder, width: 3),
                            ),
                          ),
                          blockquotePadding: const EdgeInsets.only(left: 12),
                          h1: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          h2: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          h3: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          listBullet: TextStyle(
                            fontSize: 14.5,
                            color: textColor,
                            height: 1.62,
                          ),
                          strong: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                          em: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: textColor,
                          ),
                          a: TextStyle(color: t.accent),
                        ),
                      ),
                    if (isStreaming)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: CursorBlink(color: t.accent),
                      ),
                    if (canCopy)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            _GhostButton(
                              label: 'Copy',
                              icon: Icons.copy_rounded,
                              onTap: copyToClipboard,
                            ),
                            // Read the reply aloud (streaming TTS). Hidden in
                            // live mode — the session is already speaking.
                            if (!provider.isInLiveMode) ...[
                              const SizedBox(width: 6),
                              _GhostButton(
                                label: provider.isReadingAloud(message)
                                    ? 'Stop'
                                    : 'Read aloud',
                                icon: provider.isReadingAloud(message)
                                    ? Icons.stop_rounded
                                    : Icons.volume_up_rounded,
                                onTap: () => provider.toggleReadAloud(message),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small transparent icon button used for message meta actions.
class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(icon, size: 14, color: t.text3),
      ),
    );
  }
}

/// Quiet outlined action pill under assistant messages ("Copy", etc.).
class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: t.text3),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: t.text3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final String filename;
  final String mimeType;

  const _FileChip({required this.filename, required this.mimeType});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file_rounded, size: 14, color: t.text3),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: t.text1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
