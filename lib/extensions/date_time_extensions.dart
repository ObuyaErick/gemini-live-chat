import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  String formatToString({String format = 'MMM d yyyy • hh:mm a'}) {
    return DateFormat(format).format(this);
  }
}
