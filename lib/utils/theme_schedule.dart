/// Start is inclusive, end exclusive. [end] may be 1440 (next midnight).
/// Equal times disable the night interval. 0–1440 covers the whole day.
bool isScheduledNight(DateTime now, int start, int end) {
  final minute = now.hour * 60 + now.minute;
  if (end >= 1440) return minute >= start.clamp(0, 1439);
  if (start == end) return false;
  return start < end
      ? minute >= start && minute < end
      : minute >= start || minute < end;
}

bool isAllDayNight(int start, int end) => start <= 0 && end >= 1440;
