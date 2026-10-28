import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

Future<Map<String, String>> getDeviceInfo() async {
  final deviceInfoPlugin = DeviceInfoPlugin();
  String deviceType = 'Unknown';
  String osVersion = 'Unknown';
  String deviceName = 'Unknown';

  try {
    if (!kIsWeb && Platform.isAndroid) {
      final info = await deviceInfoPlugin.androidInfo;
      deviceType = 'Android';
      osVersion =
          'Android ${info.version.release} (API ${info.version.sdkInt})';
      deviceName = '${info.manufacturer} ${info.model}';
    } else if (!kIsWeb && Platform.isIOS) {
      final info = await deviceInfoPlugin.iosInfo;
      deviceType = 'iOS';
      osVersion = 'iOS ${info.systemVersion}';
      deviceName = '${info.modelName} (${info.utsname.machine})';
    } else if (kIsWeb) {
      deviceType = 'Web';
      osVersion = 'Web Browser';
      deviceName = 'Web Client';
    }
  } catch (e) {
    debugPrint('Fehler beim Abrufen der Geräteinformationen: $e');
  }

  return {
    'device_type': deviceType,
    'os_version': osVersion,
    'device_name': deviceName,
  };
}
