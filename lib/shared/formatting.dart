part of 'package:carbonfeet/main.dart';

String _formatNumber(double number) {
  return number.toStringAsFixed(0);
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _deltaLabel(double delta) {
  final rounded = delta.abs().toStringAsFixed(0);
  if (delta < 0) {
    return '-$rounded kg';
  }
  if (delta > 0) {
    return '+$rounded kg';
  }
  return '0 kg';
}

bool _isSameCalendarDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
