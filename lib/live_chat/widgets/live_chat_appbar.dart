import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webs/live_chat/providers/live_chat_provider.dart';
import 'package:webs/models/agent_models.dart';

class LiveChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isConnected;
  final List<Agent> agents;
  final Agent? selectedAgent;
  final ValueChanged<Agent> onSelectAgent;
  final VoidCallback onToggleConnection;
  final bool isSidebarOpen;
  final VoidCallback onToggleSidebar;

  const LiveChatAppBar({
    super.key,
    required this.isConnected,
    required this.agents,
    required this.selectedAgent,
    required this.onSelectAgent,
    required this.onToggleConnection,
    required this.isSidebarOpen,
    required this.onToggleSidebar,
  });

  @override
  Size get preferredSize => const Size.fromHeight(73);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: 72,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      titleSpacing: 4,
      leading: IconButton(
        icon: Icon(
          isSidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
        ),
        tooltip: isSidebarOpen ? 'Hide sessions' : 'Show sessions',
        onPressed: onToggleSidebar,
      ),
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFD6C9),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<Agent>(
                    value: selectedAgent,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    onChanged: (a) {
                      if (a == null) return;
                      onSelectAgent(a);
                    },
                    items: agents
                        .map(
                          (a) => DropdownMenuItem<Agent>(
                            value: a,
                            child: Text(
                              a.agentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  spacing: 16,
                  children: [
                    Text(
                      isConnected
                          ? 'STATUS: CONNECTED'
                          : 'STATUS: DISCONNECTED',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Consumer<LiveChatProvider>(
                        builder: (context, chatProvider, child) => Text(
                          chatProvider.currentSessionId ?? "",
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.6,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(isConnected ? Icons.link : Icons.link_off),
          tooltip: isConnected ? 'Connected' : 'Disconnected',
          onPressed: onToggleConnection,
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE9EAF0)),
      ),
    );
  }
}
