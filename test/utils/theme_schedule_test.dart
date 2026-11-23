import 'package:modu_reader/utils/theme_schedule.dart';
import 'package:modu_reader/config/shared_preference_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('overnight interval includes start and excludes end', () {
    for (final (hour, minute, night) in [
      (21, 59, false),
      (22, 0, true),
      (23, 59, true),
      (0, 0, true),
      (6, 59, true),
      (7, 0, false),
      (12, 0, false),
    ]) {
      expect(isScheduledNight(DateTime(2026, 11, 1, hour, minute), 1320, 420),
          night);
    }
  });
  test('same-day and empty intervals', () {
    expect(isScheduledNight(DateTime(2026, 11, 1, 9), 480, 1080), true);
    expect(isScheduledNight(DateTime(2026, 11, 1, 18), 480, 1080), false);
    expect(isScheduledNight(DateTime(2026, 11, 1, 9), 480, 480), false);
  });
  test('all-day interval is night at every minute', () {
    expect(isAllDayNight(0, 1440), true);
    expect(isAllDayNight(0, 1439), false);
    for (final (hour, minute) in [(0, 0), (7, 0), (12, 0), (22, 0), (23, 59)]) {
      expect(
          isScheduledNight(DateTime(2026, 11, 1, hour, minute), 0, 1440), true);
    }
    expect(isScheduledNight(DateTime(2026, 11, 1, 21, 59), 1320, 1440), false);
    expect(isScheduledNight(DateTime(2026, 11, 1, 23, 59), 1320, 1440), true);
  });
  test('schedule persists; manual selection exits; E-Ink ignores schedule',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Prefs();
    await prefs.initPrefs();
    expect(prefs.scheduledTheme, false);
    expect(prefs.nightStartMinute, 1320);
    expect(prefs.nightEndMinute, 420);
    await prefs.saveThemeModeToPrefs('system');
    await prefs.saveThemeSchedule(enabled: true, start: 0, end: 1439);
    await prefs.initPrefs();
    expect(prefs.scheduledTheme, true);
    expect(prefs.nightStartMinute, 0);
    expect(prefs.nightEndMinute, 1439);
    await prefs.saveThemeSchedule(start: 0, end: 1440);
    expect(prefs.nightEndMinute, 1440);
    expect(prefs.scheduledNight, true);
    expect(prefs.themeMode,
        prefs.scheduledNight ? ThemeMode.dark : ThemeMode.light);
    expect(prefs.readingNightMode, prefs.scheduledNight);
    prefs.eInkMode = true;
    expect(prefs.themeMode, ThemeMode.system);
    prefs.eInkMode = false;
    await prefs.saveThemeModeToPrefs('light');
    expect(prefs.scheduledTheme, false);
    expect(prefs.themeMode, ThemeMode.light);
  });
}
