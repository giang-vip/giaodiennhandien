class ApiConstants {
  // =========================================================================
  // 🛠️ HƯỚNG DẪN CẤU HÌNH IP (ĐỌC KỸ TRƯỚC KHI CHẠY CODE)
  // =========================================================================
  //
  // 1. Dành cho MÁY ẢO ANDROID (Emulator):
  //    Đổi ipAddress thành: '10.0.2.2'
  //
  // 2. Dành cho ĐIỆN THOẠI THẬT (Kết nối cùng mạng Wifi với máy tính):
  //    Mở CMD gõ 'ipconfig' lấy IPv4 Address.
  //    Ví dụ đổi ipAddress thành: '192.168.1.21'
  //
  // TỪ NAY VỀ SAU, BẠN CHỈ CẦN SỬA DUY NHẤT DÒNG SỐ 16 NÀY KHI ĐỔI MẠNG!
  // =========================================================================

  static const String ipAddress = '192.168.67.5'; // <-- SỬA ĐỊA CHỈ IP Ở ĐÂY
  static const String port = '8081';              // <-- CỔNG SPRING BOOT

  // Đường dẫn gốc chung cho toàn bộ các API (Lớp, Phòng, Điểm danh...)
  static const String baseUrl = 'http://$ipAddress:$port/api';

  // Đường dẫn riêng dành cho chức năng Đăng nhập (Auth)
  // (Do Backend của bạn tách riêng auth ra khỏi /api hoặc dùng /api/v1/auth)
  static const String authUrl = 'http://$ipAddress:$port/auth';

  // đường dẫn của model nhận diện khuôn mặt
  // static const String faceRecognitionUrl = 'http://$ipAddress:$port/face-recognition';
  static const String aiBaseUrl = "http://192.168.67.5:8000";

}