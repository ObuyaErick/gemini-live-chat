import 'dart:async';

import 'package:webs/ui/core/alerts/app_notification.dart';
import 'package:webs/ui/core/alerts/notification_position.dart';
import 'package:flutter/material.dart';

class NotificationHost extends StatefulWidget {
  const NotificationHost({
    required this.child,
    super.key,
    this.maxNotifications = 5,
    this.spacing = 8.0,
    this.constraints,
  });

  final Widget child;
  final int maxNotifications;
  final double spacing;
  final BoxConstraints? constraints;

  @override
  State<NotificationHost> createState() => _NotificationHostState();

  /// Access the NotificationHost from the context
  static NotificationHostDelegate of(BuildContext context) {
    final delegate = context
        .dependOnInheritedWidgetOfExactType<_NotificationHostInherited>()
        ?.delegate;

    assert(
      delegate != null,
      'No NotificationHost found in context. '
      'Make sure to wrap your app with NotificationHost.',
    );

    return delegate!;
  }

  /// Access the NotificationHost from the context, returns null if not found
  static NotificationHostDelegate? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_NotificationHostInherited>()
        ?.delegate;
  }
}

/// Delegate class that provides the public API for NotificationHost
class NotificationHostDelegate {
  NotificationHostDelegate._(this._state);

  final _NotificationHostState _state;

  /// Push a notification to the host
  void pushAlert(AppNotification notification) {
    _state._addNotification(notification);
  }

  /// Remove a notification by id
  void removeAlert(String id) {
    _state._removeNotification(id);
  }

  /// Clear all notifications
  void clearAll() {
    _state._clearAll();
  }
}

/// InheritedWidget to provide access to NotificationHostDelegate
class _NotificationHostInherited extends InheritedWidget {
  const _NotificationHostInherited({
    required this.delegate,
    required super.child,
  });

  final NotificationHostDelegate delegate;

  @override
  bool updateShouldNotify(_NotificationHostInherited oldWidget) {
    return delegate != oldWidget.delegate;
  }
}

class _NotificationHostState extends State<NotificationHost> {
  final List<AppNotification> _notifications = [];
  final Map<String, Timer> _timers = {};
  late final NotificationHostDelegate _delegate;

  @override
  void initState() {
    super.initState();
    _delegate = NotificationHostDelegate._(this);
  }

  void _addNotification(AppNotification notification) {
    setState(() {
      if (_notifications.length >= widget.maxNotifications) {
        final removed = _notifications.removeAt(0);
        _timers[removed.id]?.cancel();
        _timers.remove(removed.id);
      }
      _notifications.add(notification);
    });

    _timers[notification.id] = Timer(notification.duration, () {
      _removeNotification(notification.id);
    });
  }

  void _removeNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
    _timers[id]?.cancel();
    _timers.remove(id);
  }

  void _clearAll() {
    setState(_notifications.clear);
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _NotificationHostInherited(
      delegate: _delegate,
      child: Container(
        constraints: widget.constraints,
        child: Stack(
          children: [
            widget.child,
            for (final position in NotificationPosition.values)
              Align(
                alignment: position.alignment,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final notification in _notifications.where(
                      (ntn) => ntn.position == position,
                    ))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: NotificationCard(
                          key: ValueKey(notification.id),
                          notification: notification,
                          onDismiss: () => _removeNotification(notification.id),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NotificationCard extends StatefulWidget {
  const NotificationCard({
    required this.notification,
    required this.onDismiss,
    super.key,
  });
  final AppNotification notification;
  final VoidCallback onDismiss;

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  AppNotification get notification => widget.notification;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.zero,
          color: notification.severity.bg,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              border: Border(
                bottom: BorderSide(
                  color: notification.severity.colorScheme.primary,
                  width: 4,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    notification.icon,
                    color: notification.severity.fg,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      notification.message,
                      softWrap: true,
                      maxLines: 5,
                      style: TextStyle(
                        fontSize: 14,
                        color: notification.severity.fg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: widget.onDismiss,
                    icon: Icon(Icons.close_rounded, size: 16),
                    constraints: BoxConstraints(),
                    padding: EdgeInsets.all(2),
                    style: IconButton.styleFrom(
                      backgroundColor: notification.severity.fg,
                      foregroundColor: notification.severity.bg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
