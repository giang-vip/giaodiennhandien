import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';

class CreateClassViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final payload = token.split('.')[1];
      return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      );
    } catch (e) {
      return {};
    }
  }

  Future<bool> _isTokenValid(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = _decodeJwt(token);

    if (jwt['type'] != 'access') {
      await prefs.clear();
      return false;
    }

    final exp = jwt['exp'];
    if (exp != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now >= exp) {
        await prefs.clear();
        return false;
      }
    }

    return true;
  }

  Future<bool> createClassAPI({
    required String title,
    required String description,
    required List<int> locationIds,
    required String startDate,
    required String endDate,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        print("NO TOKEN");
        return false;
      }

      final isValid = await _isTokenValid(token);
      if (!isValid) {
        print("TOKEN INVALID");
        return false;
      }

      final jwtData = _decodeJwt(token);
      final sub = jwtData['sub'];

      if (sub == null) {
        print("TOKEN KHÔNG CÓ SUB");
        return false;
      }

      final int myTeacherId = int.tryParse(sub.toString()) ?? 0;

      if (myTeacherId == 0) {
        print("TEACHER ID INVALID");
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/classrooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "teacherId": myTeacherId,
          "title": title,
          "description": description,
          "startDate": startDate,
          "endDate": endDate,
          "locationIds": locationIds,
        }),
      );

      print("CREATE STATUS: ${response.statusCode}");
      print("CREATE BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("CREATE SUCCESS");
        return true;
      } else {
        print("CREATE FAIL");
        return false;
      }
    } catch (e) {
      print("CREATE CLASS ERROR: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}