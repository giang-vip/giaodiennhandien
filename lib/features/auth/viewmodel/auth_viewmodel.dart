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

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Login thất bại');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
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
      // final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // 🔥 xoá sạch token

      // ✅ LƯU RÕ RÀNG (QUAN TRỌNG NHẤT)
      await prefs.setString('access_token', accessToken);

      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString('refresh_token', refreshToken);
      }

      _isLoading = false;
      notifyListeners();

      String role = rolesData.toString().toUpperCase();

      if (role.contains('ADMIN') || role.contains('LEADER')) {
        return 'teacher';
      }
      return 'student';
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      print("LOGIN ERROR: $e");
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // ✅ LẤY ACCESS TOKEN (SỬA KEY)
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // (tuỳ dùng)
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}