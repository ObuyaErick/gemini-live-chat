import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  String formatToString({String format = 'MMM d yyyy • hh:mm a'}) {
    return DateFormat(format).format(this);
  }

  /// 12-hour clock time, e.g. `3:07 PM`.
  String get chatTime => DateFormat('h:mm a').format(this);

  /// The date-pill label shown at the top of a chat thread, e.g.
  /// `TODAY, 3:07 PM`.
  String get chatTodayPill => 'TODAY, $chatTime';
}
