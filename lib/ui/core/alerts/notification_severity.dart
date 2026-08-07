import 'package:flutter/material.dart';

enum NotificationSeverity {
  success,
  info,
  warning,
  error;

  Color get bg => switch (this) {
    NotificationSeverity.success => Colors.green.withValues(alpha: 0.8),
    NotificationSeverity.info => Colors.blue.withValues(alpha: 0.8),
    NotificationSeverity.warning => Colors.orange.withValues(alpha: 0.8),
    NotificationSeverity.error => Colors.red.withValues(alpha: 0.8),
  };

  ColorScheme get colorScheme => ColorScheme.fromSeed(seedColor: bg);

  Color get fg => switch (this) {
    NotificationSeverity.success => Colors.white,
    NotificationSeverity.info => Colors.white,
    NotificationSeverity.warning => Colors.white,
    NotificationSeverity.error => Colors.white,
  };
  IconData get icon => switch (this) {
    NotificationSeverity.success => Icons.check_circle,
    NotificationSeverity.info => Icons.info,
    NotificationSeverity.warning => Icons.warning,
    NotificationSeverity.error => Icons.error,
  };
}
