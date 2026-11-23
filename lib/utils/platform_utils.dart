import 'dart:io';

import 'package:flutter/foundation.dart';

enum AnxPlatformEnum { android, ios, macos, windows, ohos, linux }

class AnxPlatform {
  static AnxPlatformEnum get type => kIsWeb
      ? throw UnsupportedError('Web is not a native platform')
      : fromOperatingSystem(Platform.operatingSystem);

  /// HarmonyOS NEXT uses the OHOS Flutter engine, not the Android runtime.
  /// Keep this mapping testable without pretending the host is a real device.
  static AnxPlatformEnum fromOperatingSystem(String operatingSystem) =>
      switch (operatingSystem) {
        'android' => AnxPlatformEnum.android,
        'ios' => AnxPlatformEnum.ios,
        'macos' => AnxPlatformEnum.macos,
        'windows' => AnxPlatformEnum.windows,
        'linux' => AnxPlatformEnum.linux,
        'ohos' => AnxPlatformEnum.ohos,
        _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
      };

  // Web has no dart:io Platform. These stay false so UI checks do not throw.
  static bool get isAndroid => !kIsWeb && type == AnxPlatformEnum.android;
  static bool get isIOS => !kIsWeb && type == AnxPlatformEnum.ios;
  static bool get isMacOS => !kIsWeb && type == AnxPlatformEnum.macos;
  static bool get isWindows => !kIsWeb && type == AnxPlatformEnum.windows;
  static bool get isOhos => !kIsWeb && type == AnxPlatformEnum.ohos;
  static bool get isLinux => !kIsWeb && type == AnxPlatformEnum.linux;

  static bool get isMobile => isAndroid || isIOS || isOhos;

  static bool get isDesktop => isWindows || isMacOS || isLinux;
}
