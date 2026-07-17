/// A specific entity the user has selected within a module (row, node, …),
/// sent as part of a [ChatContext] frame.
class ChatContextSelection {
  final String type;
  final String id;
  final String? label;

  const ChatContextSelection({
    required this.type,
    required this.id,
    this.label,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    if (label != null) 'label': label,
  };
}

/// Module context injected into a Concierge session so the model is aware of
/// the page the user is looking at. Sent as a `{ "context": … }` frame.
class ChatContext {
  final String module;
  final String page;
  final String? path;
  final String? title;
  final Map<String, dynamic>? params;
  final ChatContextSelection? selection;

  const ChatContext({
    required this.module,
    required this.page,
    this.path,
    this.title,
    this.params,
    this.selection,
  });

  Map<String, dynamic> toJson() => {
    'module': module,
    'page': page,
    if (path != null) 'path': path,
    if (title != null) 'title': title,
    if (params != null) 'params': params,
    if (selection != null) 'selection': selection!.toJson(),
  };
}
