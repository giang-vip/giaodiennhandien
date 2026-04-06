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
      return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))));
    } catch(e) { return {}; }
  }

  Future<bool> createClassAPI({required String title, required String description, required int teacherId, required List<int> locationIds}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final jwtData = _decodeJwt(token!);
      final int myTeacherId = int.parse(jwtData['sub']!.toString());

      final response = await http.post(
        Uri.parse('$_baseUrl/classrooms'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          "teacherId": myTeacherId,
          "title": title,
          "description": description,
          "startDate": DateTime.now().toIso8601String().split('T')[0],
          "endDate": DateTime.now().add(const Duration(days: 90)).toIso8601String().split('T')[0],
          "locationIds": locationIds
        }),
      );

      return (response.statusCode == 200 || response.statusCode == 201);
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}