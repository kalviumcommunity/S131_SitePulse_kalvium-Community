import 'package:flutter/material.dart';

DateTimeRange lastSevenDays({DateTime? now}) {
  final today = now ?? DateTime.now();
  final end = DateTime(today.year, today.month, today.day, 23, 59, 59);
  return DateTimeRange(
    start: DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 6)),
    end: end,
  );
}
