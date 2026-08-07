import 'package:flutter/material.dart';

enum NotificationPosition {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  Alignment get alignment => switch (this) {
    topLeft => Alignment.topLeft,
    topCenter => Alignment.topCenter,
    topRight => Alignment.topRight,
    centerLeft => Alignment.centerLeft,
    center => Alignment.center,
    centerRight => Alignment.centerRight,
    bottomLeft => Alignment.bottomLeft,
    bottomCenter => Alignment.bottomCenter,
    bottomRight => Alignment.bottomRight,
  };
}
