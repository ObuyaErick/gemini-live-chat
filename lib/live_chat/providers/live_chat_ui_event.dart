/// One-shot UI effects the [LiveChatProvider] needs the widget layer to carry
/// out. The provider owns no [BuildContext], so instead of showing snackbars or
/// scrolling directly it emits these on a stream the screen listens to.
sealed class LiveChatUiEvent {
  const LiveChatUiEvent();
}

/// How urgent/positive a [ShowSnackBar] is. Deliberately presentation-agnostic
/// (no `Color`/`IconData`) so the provider layer doesn't reach into `ui/` —
/// the screen maps this to whatever visual treatment it uses.
enum SnackSeverity { info, success, warning, error }

/// Show a transient message (agent switch, navigate intent, context ack,
/// upload errors).
class ShowSnackBar extends LiveChatUiEvent {
  final String message;
  final Duration duration;
  final SnackSeverity severity;
  const ShowSnackBar(
    this.message, {
    this.duration = const Duration(seconds: 3),
    this.severity = SnackSeverity.info,
  });
}

/// Ask the transcript view to scroll to the newest message.
class ScrollToBottom extends LiveChatUiEvent {
  const ScrollToBottom();
}
