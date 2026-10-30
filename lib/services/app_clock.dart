/// Calendar and display time for the gym's Asia/Ho_Chi_Minh timezone (UTC+7).
class AppClock {
  AppClock._();
  static DateTime now() => inVietnam(DateTime.now());
  static DateTime inVietnam(DateTime instant) {
    final value = instant.toUtc().add(const Duration(hours: 7));
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    );
  }

  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static DateTime get today => day(now());
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static String date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  static String time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
}
