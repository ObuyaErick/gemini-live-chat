import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webs/extensions/date_time_extensions.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/providers/live_chat_provider.dart';

class SessionsSidebar extends StatelessWidget {
  final ValueChanged<ChatSession> onSelectSession;
  final VoidCallback onNewSession;
  final bool isOpen;
  final VoidCallback onToggle;

  const SessionsSidebar({
    super.key,
    required this.onSelectSession,
    required this.onNewSession,
    required this.isOpen,
    required this.onToggle,
  });

  static const double _openWidth = 280;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: isOpen ? _openWidth : 0,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: _openWidth,
          child: SizedBox(width: _openWidth, child: _buildContent(context)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final provider = context.watch<LiveChatProvider>();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE9EAF0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE9EAF0))),
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Previous sessions',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'Refresh',
                  onPressed: provider.loadingSessions
                      ? null
                      : () {
                          final agentId = provider.currentAgentId;
                          if (agentId != null) provider.loadSessions(agentId);
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  tooltip: 'Collapse',
                  onPressed: onToggle,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New session'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: Color(0xFFE3E5EE)),
                  foregroundColor: const Color(0xFF1F2330),
                  textStyle: const TextStyle(
                    fontSize: 13,
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
              onPressed: () {
                final agentId = provider.currentAgentId;
                if (agentId != null) provider.loadSessions(agentId);
              },
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
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool selected;
  final VoidCallback onTap;

  const _SessionTile({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = session.createdAt != null
        ? session.createdAt!.formatToString(format: "MMM d, hh:mm a")
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: selected ? const Color(0xFFEEF1FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.preview ?? session.sessionId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: const Color(0xFF1F2330),
                  ),
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF747787),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
