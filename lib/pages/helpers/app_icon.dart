import 'dart:io';

import 'package:flutter/services.dart';
import 'package:minimalauncher/variables/strings.dart';

final Map<String, Future<String>> _iconPathCache = {};

bool doesIconFileExist(String packageName) {
  String iconFileName = 'icon_$packageName.png';
  String iconFilePath = '/data/user/0/$launcherPackageName/cache/$iconFileName';

  File iconFile = File(iconFilePath);
  return iconFile.existsSync();
}

Future<String> getAppIcon(String packageName) =>
    _iconPathCache.putIfAbsent(packageName, () async {
      if (doesIconFileExist(packageName)) {
        return '/data/user/0/$launcherPackageName/cache/icon_$packageName.png';
      }

      final String? appIconPath = await _channel
          .invokeMethod('getAppIconPath', {'packageName': packageName});
      return appIconPath ?? '';
    });

const MethodChannel _channel = MethodChannel('main_channel');
