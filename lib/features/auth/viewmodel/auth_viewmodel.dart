import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';

class AuthViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final String _baseUrl = ApiConstants.authUrl;

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

      print("STATUS CODE: ${response.statusCode}");
      print("RESPONSE BODY: ${response.body}");

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? 'Login thất bại');
      }

      final data = responseData['data'];
      if (data == null) {
        throw Exception("Response không có data");
      }

      final String? accessToken = data['accessToken'];
      final String? refreshToken = data['refreshToken'];
      final dynamic rolesData = data['authorities'];

      print("ACCESS TOKEN: $accessToken");
      print("REFRESH TOKEN: $refreshToken");

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception("AccessToken null");
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('access_token', accessToken);

      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString('refresh_token', refreshToken);
      }

      final savedToken = prefs.getString('access_token');
      print("SAVED TOKEN: $savedToken");

      String role = 'student';
      if (rolesData is List && rolesData.isNotEmpty) {
        final firstRole =
            rolesData[0]['authority']?.toString().toUpperCase() ?? '';

        if (firstRole.contains('ADMIN') || firstRole.contains('LEADER')) {
          role = 'teacher';
        }
      }

      _isLoading = false;
      notifyListeners();

      return role;
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      print("LOGIN ERROR: $e");
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<String> sendForgotPasswordOtp(String usernameOrEmail) async {
    try {
      final url = Uri.parse('$_baseUrl/forgot-password/send-otp');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usernameOrEmail': usernameOrEmail,
        }),
      );

      print("SEND OTP STATUS: ${response.statusCode}");
      print("SEND OTP BODY: ${response.body}");

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(responseData['message'] ?? 'Gửi OTP thất bại');
      }

      return responseData['message'] ?? 'Đã gửi mã OTP thành công';
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<String> resetForgotPassword({
    required String usernameOrEmail,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/forgot-password/reset');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usernameOrEmail': usernameOrEmail,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );

      print("RESET PASSWORD STATUS: ${response.statusCode}");
      print("RESET PASSWORD BODY: ${response.body}");

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          responseData['message'] ?? 'Đặt lại mật khẩu thất bại',
        );
      }

      return responseData['message'] ?? 'Đặt lại mật khẩu thành công';
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}