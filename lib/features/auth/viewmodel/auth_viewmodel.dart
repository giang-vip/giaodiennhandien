import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';

class AuthViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // LƯU Ý: Đổi IP này thành IP máy tính của bạn mạng LAN (ví dụ: 192.168.1.x)
  // Hoặc dùng 10.0.2.2 nếu bạn chạy bằng Android Emulator
  // máy điện thoại thì ipconfig copy ipv4 sửa vào nha
  // Hoặc localhost nếu chạy trên iOS Simulator / Web
  // final String _baseUrl = 'http://192.168.1.21:8081/auth';
  // ĐÃ FIX: Lấy đường dẫn Đăng nhập từ file cấu hình chung!
  // (Nó sẽ tự động hiểu là 10.0.2.2 nếu bạn set ở api_constants.dart)
  final String _baseUrl = '${ApiConstants.authUrl}';

  Future<String?> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/login');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      // --- THÊM 2 DÒNG NÀY VÀO ĐỂ XEM BACKEND TRẢ VỀ CÁI GÌ ---
      print("MÃ TRẠNG THÁI TỪ SERVER: ${response.statusCode}");
      print("NỘI DUNG SERVER TRẢ VỀ: '${response.body}'");
      // -------------------------------------------------------

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200) {
        // Parse JSON trả về từ backend
        // (Cấu trúc này phụ thuộc vào class LoginResponseDto / JwtResponse của bạn)
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Giả sử API của bạn trả về data bọc trong trường "data" hoặc trực tiếp
        // Cần chỉnh sửa các key 'accessToken' và 'roles' theo đúng JSON backend trả về
        final String? token = responseData['accessToken'] ?? responseData['data']?['accessToken'];

        // Backend thường trả về List các role hoặc 1 string role
        // Đã thêm 'authorities' để khớp với LoginResponseDto của Spring Boot
        final dynamic rolesData = responseData['authorities'] ?? responseData['data']?['authorities'] ?? responseData['roles'];

        if (token != null) {
          // Lưu token vào thiết bị
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);

          // Phân quyền điều hướng
          String userRole = rolesData.toString().toUpperCase();
          if (userRole.contains('ROLE_ADMIN') || userRole.contains('ROLE_LEADER') || userRole.contains('ADMIN')) {
            return 'teacher';
          } else {
            return 'student'; // Mặc định ROLE_USER là student
          }
        } else {
          throw Exception("Không tìm thấy Token trong phản hồi");
        }
      } else {
        // Xử lý lỗi (sai pass, user không tồn tại...)
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Đăng nhập thất bại');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      // THÊM DÒNG NÀY ĐỂ IN LỖI RA CONSOLE:
      print("LỖI ĐĂNG NHẬP: $e");

      // Ném lỗi ra màn hình UI để hiển thị
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // Hàm hỗ trợ đăng xuất
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    // Thực hiện điều hướng về login ở UI
  }
}