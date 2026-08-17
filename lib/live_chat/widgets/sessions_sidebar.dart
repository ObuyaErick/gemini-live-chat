import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webs/extensions/date_time_extensions.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/providers/live_chat_provider.dart';
import 'package:webs/ui/core/app_theme.dart';

class SessionsSidebar extends StatelessWidget {
  final ValueChanged<ChatSession> onSelectSession;
  final VoidCallback onNewSession;
  final ValueChanged<ChatSession> onEvictSession;
  final VoidCallback onEvictAllSessions;
  final bool isOpen;
  final VoidCallback onToggle;

  const SessionsSidebar({
    super.key,
    required this.onSelectSession,
    required this.onNewSession,
    required this.onEvictSession,
    required this.onEvictAllSessions,
    required this.isOpen,
    required this.onToggle,
  });

  static const double openWidth = 320;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: isOpen ? openWidth : 0,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: openWidth,
          child: SizedBox(width: openWidth, child: _buildContent(context)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final provider = context.watch<LiveChatProvider>();
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        border: Border(right: BorderSide(color: t.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Conversations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.text1,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, size: 18, color: t.text2),
                  tooltip: 'Refresh',
                  onPressed: provider.loadingSessions
                      ? null
                      : provider.loadSessions,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_sweep_rounded,
                    size: 18,
                    color: t.text2,
                  ),
                  tooltip: 'Clear all sessions',
                  onPressed: provider.sessions.isEmpty
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Clear all sessions?'),
                              content: const Text(
                                'All your sessions will be removed from the cache.',
                                style: TextStyle(fontSize: 13),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFB42318),
                                  ),
                                  child: const Text('Clear all'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) onEvictAllSessions();
                        },
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: t.text2,
                  ),
                  tooltip: 'Collapse',
                  onPressed: onToggle,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New chat'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: t.accent,
                  foregroundColor: t.onAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: onNewSession,
              ),
            ),
          ),
          Expanded(child: _buildList(context, provider)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, LiveChatProvider provider) {
    if (provider.loadingSessions) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (provider.sessionsError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              provider.sessionsError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB42318)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: provider.loadSessions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final sessions = provider.sessionsByDateDesc;
    if (sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No previous sessions',
            style: TextStyle(fontSize: 12, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, i) {
        final s = sessions[i];
        final selected = s.sessionId == provider.currentSessionId;
        return _SessionTile(
          session: s,
          selected: selected,
          onTap: () => onSelectSession(s),
          onEvict: () => onEvictSession(s),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEvict;

  const _SessionTile({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onEvict,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dateStr = session.createdAt != null
        ? session.createdAt!.formatToString(format: "MMM d, hh:mm a")
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: selected ? t.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: t.bg3,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? t.accentBorder : Colors.transparent,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.displayLabel ?? session.sessionId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: t.text1,
                        ),
                      ),
                      if (session.participantAgents.length > 1) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            for (
                              int i = 0;
                              i < session.participantAgents.length && i < 3;
                              i++
                            )
                              Align(
                                widthFactor: i == 0 ? 1 : 0.62,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    gradient: t.accentGradient,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: t.bg2, width: 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    session
                                        .participantAgents[i]
                                        .characters
                                        .first
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: t.onAccent,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              'shared',
                              style: TextStyle(fontSize: 10.5, color: t.text3),
                            ),
                          ],
                        ),
                      ],
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(fontSize: 11, color: t.text3),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete session?'),
                        content: Text(
                          session.displayLabel ?? session.sessionId,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF747787),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFB42318),
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) onEvict();
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  color: t.text3,
                  tooltip: 'Delete session',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
