import 'package:flutter/material.dart';
import 'package:webs/models/agent_models.dart';
import 'package:webs/ui/core/app_theme.dart';
import 'package:webs/ui/core/theme_controller.dart';

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
  Size get preferredSize => const Size.fromHeight(65);

  String _initial(Agent? a) {
    final n = a?.agentName.trim() ?? '';
    return n.isEmpty ? 'A' : n.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = ThemeController.isDark(context);
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: t.bgApp,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 4,
      leadingWidth: 52,
      leading: IconButton(
        icon: Icon(
          isSidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
          color: t.text2,
        ),
        tooltip: isSidebarOpen ? 'Hide sessions' : 'Show sessions',
        onPressed: onToggleSidebar,
      ),
      title: Align(
        alignment: Alignment.centerLeft,
        child: _AgentSwitcher(
          agents: agents,
          selectedAgent: selectedAgent,
          onSelectAgent: onSelectAgent,
          initial: _initial(selectedAgent),
        ),
      ),
      actions: [
        _ConnectionPill(isConnected: isConnected, onTap: onToggleConnection),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () => ThemeController.toggle(context),
          tooltip: dark ? 'Light mode' : 'Dark mode',
          icon: Icon(
            dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 19,
            color: t.text2,
          ),
        ),
        const SizedBox(width: 10),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: t.border),
      ),
    );
  }
}

class _AgentSwitcher extends StatelessWidget {
  final List<Agent> agents;
  final Agent? selectedAgent;
  final ValueChanged<Agent> onSelectAgent;
  final String initial;

  const _AgentSwitcher({
    required this.agents,
    required this.selectedAgent,
    required this.onSelectAgent,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopupMenuButton<Agent>(
      tooltip: 'Switch agent',
      offset: const Offset(0, 48),
      color: t.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.borderStrong),
      ),
      onSelected: onSelectAgent,
      itemBuilder: (context) => [
        for (final a in agents)
          PopupMenuItem<Agent>(
            value: a,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: t.accentGradient,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    a.agentName.trim().isEmpty
                        ? 'A'
                        : a.agentName.trim().characters.first.toUpperCase(),
                    style: TextStyle(
                      color: t.onAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    a.agentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.text1,
                    ),
                  ),
                ),
                if (a.agentName == selectedAgent?.agentName)
                  Icon(Icons.check_rounded, size: 16, color: t.accent),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        decoration: BoxDecoration(
          color: t.bgApp,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: t.accentGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  color: t.onAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedAgent?.agentName ?? 'Agent',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.text1,
                  ),
                ),
                Text(
                  'agent · online',
                  style: AppTheme.mono(size: 10, color: t.text3),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: t.text3),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onTap;

  const _ConnectionPill({required this.isConnected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = isConnected ? t.success : t.text3;
    final bg = isConnected ? t.successSoft : t.bg3;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isConnected ? t.success : t.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
