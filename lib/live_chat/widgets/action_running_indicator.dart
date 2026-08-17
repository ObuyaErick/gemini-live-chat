import 'package:flutter/material.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/ui/core/app_theme.dart';

/// Shown between the user's Confirm click and the action's outcome, driven by
/// the `action_result` `running` ack. A real action — a publish, a bulk
/// write — routinely takes ten seconds or more; without this there is no frame
/// at all between the click and the result, and the screen looks frozen.
class ActionRunningIndicator extends StatelessWidget {
  final ActionRun run;

  const ActionRunningIndicator({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.borderStrong),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              run.summary ?? 'Running ${run.toolName}…',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, height: 1.4, color: t.text2),
            ),
          ),
        ],
      ),
    );
  }
}
