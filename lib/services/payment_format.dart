String formatVnd(Object? amount) {
  final value = (amount as num? ?? 0).round().toString();
  return '${value.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')} đ';
}

String packageTerm(Map<String, dynamic> package) {
  final months = (package['duration_months'] as num? ?? 0).toInt();
  return months > 0 ? '$months tháng' : '${package['duration_days']} ngày';
}
