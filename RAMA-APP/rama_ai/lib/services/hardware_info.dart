import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class HardwareInfoService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<Map<String, String>> getAndroidHardwareInfo() async {
    if (!Platform.isAndroid) return {'OS': Platform.operatingSystem};

    try {
      final androidInfo = await _deviceInfo.androidInfo;
      return {
        'Device': '${androidInfo.manufacturer} ${androidInfo.model}',
        'Android Version': androidInfo.version.release,
        'API Level': androidInfo.version.sdkInt.toString(),
        'Hardware': androidInfo.hardware,
        'Supported ABIs': androidInfo.supportedAbis.join(', '),
      };
    } catch (e) {
      return {'Error': 'Could not read hardware info: $e'};
    }
  }
}
