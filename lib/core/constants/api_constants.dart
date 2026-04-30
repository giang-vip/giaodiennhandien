class ApiConstants {
  // ================= CHỌN 1 CHẾ ĐỘ =================
  static const bool useWindowsDesktop = true;
  static const bool useAndroidEmulator = false;
  static const bool usePhysicalDevice = false;

  // IP Wi-Fi thật của máy tính (cho điện thoại thật truy cập)
  static const String physicalDeviceIp = '192.168.1.4';

  static const String port = '8081';

  static String get host {
    if (useAndroidEmulator) return '10.0.2.2';
    if (usePhysicalDevice) return physicalDeviceIp;
    return '127.0.0.1'; // Windows desktop
  }

  // ================= FACE APIs =================
  static String get faceRegister => '$baseUrl/face/register';
  static String get faceRecognize => '$baseUrl/face/recognize';

  // ================= BACKEND APIs =================
  static String get baseUrl => 'http://$host:$port/api';

  // Login
  static String get authUrl => 'http://$host:$port/auth';

  // ================= PYTHON AI SERVICE =================
  static const String aiBaseUrl = 'http://192.168.57.109:8000';
}