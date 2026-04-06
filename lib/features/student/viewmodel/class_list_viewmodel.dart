import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/app_models.dart';

class ClassListViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AppClassModel> _availableClasses = [];
  List<AppClassModel> get availableClasses => _availableClasses;

  // ================= JWT =================
  int _getMyStudentId(String token) {
    try {
      final payload = token.split('.')[1];
      final decoded = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(payload))));
      return int.parse(decoded['sub'].toString());
    } catch (e) {
      return 0;
    }
  }

  // ================= FETCH =================
  Future<void> fetchAvailableClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ FIX QUAN TRỌNG: dùng access_token
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        throw Exception("❌ Chưa đăng nhập");
      }

      print("TOKEN FETCH: $token");

      final myStudentId = _getMyStudentId(token);

      // ================= STEP 1 =================
      final myRegResponse = await http.get(
        Uri.parse('$_baseUrl/class-registrations/$myStudentId/classes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      Set<String> registeredIds = {};

      if (myRegResponse.statusCode == 200) {
        final decoded =
        jsonDecode(utf8.decode(myRegResponse.bodyBytes));

        final List list = decoded['data'] is List
            ? decoded['data']
            : (decoded['data']?['content'] ?? []);

        for (var item in list) {
          final cId = item['classId']?.toString() ??
              item['classRoom']?['classId']?.toString() ??
              '0';
          registeredIds.add(cId);
        }
      }

      // ================= STEP 2 =================
      final response = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded =
        jsonDecode(utf8.decode(response.bodyBytes));

        final List list = decoded['data'] is List
            ? decoded['data']
            : (decoded['data']?['content'] ?? []);

        _availableClasses = list
            .where((item) {
          final checkId = item['classId']?.toString() ??
              item['id']?.toString() ??
              '0';
          return !registeredIds.contains(checkId);
        })
            .map((item) => AppClassModel(
          id: item['classId']?.toString() ??
              item['id']?.toString() ??
              '0',
          teacherId:
          item['teacherId']?.toString() ?? '0',
          className:
          item['title'] ?? 'Chưa có tên',
          description:
          item['description'] ?? 'Chưa có mô tả',
          teacherName:
          item['teacherName'] ?? 'Giảng viên',
          startTime:
          item['startDate'] ?? 'N/A',
          endTime:
          item['endDate'] ?? 'N/A',
        ))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception("❌ Unauthorized");
      }
    } catch (e) {
      print("❌ LỖI LẤY LỚP: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================= REGISTER =================
  Future<bool> registerClass(String classId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();

      // ✅ FIX QUAN TRỌNG
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        throw Exception("❌ Chưa đăng nhập");
      }

      final myStudentId = _getMyStudentId(token);

      final bodyData = {
        "classId": int.parse(classId),
        "studentId": myStudentId
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/class-registrations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(bodyData),
      );

      return response.statusCode == 200 ||
          response.statusCode == 201;
    } catch (e) {
      print("❌ REGISTER ERROR: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}