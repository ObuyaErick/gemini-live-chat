import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/widgets/avatar.dart';
import 'package:webs/live_chat/widgets/cursor_blink.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String agentName;
  final String Function(DateTime) formatTime;

  const MessageBubble({
    super.key,
    required this.message,
    required this.agentName,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isError = message.status == MessageStatus.error;
    final isStreaming = message.status == MessageStatus.streaming;
    final colorScheme = Theme.of(context).colorScheme;

    void copyToClipboard() {
      Clipboard.setData(ClipboardData(text: message.content));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 200,
        ),
      );
    }

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onLongPress: copyToClipboard,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F2F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF111827),
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: copyToClipboard,
                    icon: const Icon(Icons.copy_rounded),
                    iconSize: 14,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: const Color(0xFFADB5BD),
                    tooltip: 'Copy',
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${formatTime(message.createdAt)} • Delivered',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (isError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Avatar(
              icon: Icons.error_outline,
              bg: Color(0xFFFFE4E4),
              fg: Color(0xFFB42318),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYSTEM ERROR  •  ${formatTime(message.createdAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFFB42318),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFC9C9)),
                    ),
                    child: Text(
                      message.content,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Color(0xFFB42318),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    const textColor = Color(0xFF111827);
    final canCopy = !isStreaming && message.content.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Avatar(icon: Icons.support_agent_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agentName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onLongPress: canCopy ? copyToClipboard : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE9EAF0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.imageBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              message.imageBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        if (message.content.isNotEmpty) ...[
                          if (message.imageBytes != null)
                            const SizedBox(height: 10),
                          MarkdownBody(
                            data: message.content,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                fontSize: 14,
                                color: textColor,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                              code: TextStyle(
                                fontSize: 13,
                                color: textColor,
                                backgroundColor: const Color(0xFFF1F2F6),
                                fontFamily: 'monospace',
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: const Color(0xFFF1F2F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              blockquoteDecoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: Color(0xFFADB5BD),
                                    width: 3,
                                  ),
                                ),
                              ),
                              blockquotePadding: const EdgeInsets.only(left: 12),
                              h1: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              h2: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              h3: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              listBullet: const TextStyle(
                                fontSize: 14,
                                color: textColor,
                                height: 1.45,
                              ),
                              strong: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              em: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                        if (isStreaming)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: CursorBlink(
                              color: textColor.withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (canCopy)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton(
                      onPressed: copyToClipboard,
                      icon: const Icon(Icons.copy_rounded),
                      iconSize: 14,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: const Color(0xFFADB5BD),
                      tooltip: 'Copy',
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
