/// One-shot UI effects the [LiveChatProvider] needs the widget layer to carry
/// out. The provider owns no [BuildContext], so instead of showing snackbars or
/// scrolling directly it emits these on a stream the screen listens to.
sealed class LiveChatUiEvent {
  const LiveChatUiEvent();
}

/// Show a transient message (agent switch, navigate intent, context ack, upload
/// errors). [dismissible] adds a manual dismiss action.
class ShowSnackBar extends LiveChatUiEvent {
  final String message;
  final Duration duration;
  final bool dismissible;
  const ShowSnackBar(
    this.message, {
    this.duration = const Duration(seconds: 3),
    this.dismissible = false,
  });
}

/// Ask the transcript view to scroll to the newest message.
class ScrollToBottom extends LiveChatUiEvent {
  const ScrollToBottom();
}
