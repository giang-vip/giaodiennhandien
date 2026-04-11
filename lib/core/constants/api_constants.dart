class ApiConstants {
  // ================= CHỌN 1 CHẾ ĐỘ =================
  static const bool useWindowsDesktop = true;
  static const bool useAndroidEmulator = false;
  static const bool usePhysicalDevice = false;

  // IP máy tính khi chạy bằng điện thoại thật
  static const String physicalDeviceIp = '192.168.100.127';

  static const String port = '8081';

  static String get host {
    if (useAndroidEmulator) return '10.0.2.2';
    if (usePhysicalDevice) return physicalDeviceIp;
    return '127.0.0.1'; // Windows desktop
  }

  // API chung
  static String get baseUrl => 'http://$host:$port/api';

  // API login
  static String get authUrl => 'http://$host:$port/auth';

  // AI service
  static const String aiBaseUrl = 'http://192.168.65.1:8000';
}