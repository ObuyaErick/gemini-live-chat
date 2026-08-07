import 'package:webs/ui/core/alerts/notification_position.dart';
import 'package:webs/ui/core/alerts/notification_severity.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class AppNotification {

  AppNotification({
    required this.message,
    required this.severity,
    this.position = NotificationPosition.topCenter,
    this.duration = const Duration(seconds: 5),
    IconData? icon,
  }) : id = Uuid().v4(),
       timestamp = DateTime.now().millisecondsSinceEpoch,
       _icon = icon;

  AppNotification.success(
    String message, {
    NotificationPosition position = NotificationPosition.topCenter,
    Duration duration = const Duration(seconds: 5),
    IconData? icon,
  }) : this(
         message: message,
         position: position,
         severity: NotificationSeverity.success,
         duration: duration,
         icon: icon,
       );

  AppNotification.info(
    String message, {
    NotificationPosition position = NotificationPosition.topCenter,
    Duration duration = const Duration(seconds: 5),
    IconData? icon,
  }) : this(
         message: message,
         position: position,
         severity: NotificationSeverity.info,
         duration: duration,
         icon: icon,
       );

  AppNotification.warning(
    String message, {
    NotificationPosition position = NotificationPosition.topCenter,
    Duration duration = const Duration(seconds: 5),
    IconData? icon,
  }) : this(
         message: message,
         position: position,
         severity: NotificationSeverity.warning,
         duration: duration,
         icon: icon,
       );

  AppNotification.error(
    String message, {
    NotificationPosition position = NotificationPosition.topCenter,
    Duration duration = const Duration(seconds: 5),
    IconData? icon,
  }) : this(
         message: message,
         position: position,
         severity: NotificationSeverity.error,
         duration: duration,
         icon: icon,
       );
  final String id;
  final int timestamp;
  final String message;
  final NotificationPosition position;
  final NotificationSeverity severity;
  final Duration duration;
  final IconData? _icon;
  IconData get icon => _icon ?? severity.icon;

  AppNotification copyWith({
    String? message,
    NotificationPosition? position,
    NotificationSeverity? severity,
    Duration? duration,
    IconData? icon,
  }) {
    return AppNotification(
      message: message ?? this.message,
      position: position ?? this.position,
      severity: severity ?? this.severity,
      duration: duration ?? this.duration,
      icon: icon ?? _icon,
    );
  }
}

class MutationStatus<T> {

  MutationStatus({
    required this.message,
    required this.severity,
    this.resource,
  });
  String message;
  NotificationSeverity severity;
  T? resource;
}

extension MutationStatusExtensions<T> on MutationStatus<T> {
  bool get isSuccess =>
      severity == NotificationSeverity.success && resource != null;

  AppNotification get notification =>
      AppNotification(message: message, severity: severity);

  MutationStatus<T> copyWith({
    String? message,
    NotificationSeverity? severity,
  }) {
    return MutationStatus(
      message: message ?? this.message,
      severity: severity ?? this.severity,
      resource: resource,
    );
  }
}
