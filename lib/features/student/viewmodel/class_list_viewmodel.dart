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

  int _getMyStudentId(String token) {
    try {
      final payload = token.split('.')[1];
      final decoded = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))));
      return int.parse(decoded['sub'].toString());
    } catch (e) {
      return 0;
    }
  }

  Future<void> fetchAvailableClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final myStudentId = _getMyStudentId(token!);

      // BƯỚC 1: Lấy danh sách ID đã đăng ký
      final myRegResponse = await http.get(
        Uri.parse('$_baseUrl/class-registrations/$myStudentId/classes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      Set<String> registeredIds = {};
      if (myRegResponse.statusCode == 200) {
        final List<dynamic> myRegData = jsonDecode(utf8.decode(myRegResponse.bodyBytes));
        for (var item in myRegData) {
          final cId = item['classId']?.toString() ?? item['classRoom']?['classId']?.toString() ?? '0';
          registeredIds.add(cId);
        }
      }

      // BƯỚC 2: Lấy tất cả thông tin lớp và CHỈ GIỮ LẠI LỚP CHƯA ĐĂNG KÝ
      final response = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        _availableClasses = (data['content'] as List)
            .where((item) {
          final checkId = item['classId']?.toString() ?? item['id']?.toString() ?? '0';
          return !registeredIds.contains(checkId);
        })
            .map((item) => AppClassModel(
          id: item['classId']?.toString() ?? item['id']?.toString() ?? '0',
          teacherId: item['teacherId']?.toString() ?? '0',
          className: item['title'] ?? 'Chưa có tên',
          description: item['description'] ?? 'Chưa có mô tả',
          teacherName: item['teacherName'] ?? 'Giảng viên',
          startTime: item['startDate'] ?? 'N/A',
          endTime: item['endDate'] ?? 'N/A',
        )).toList();
      }
    } catch (e) {
      print("❌ LỖI LẤY LỚP: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerClass(String classId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final myStudentId = _getMyStudentId(token!);

      final bodyData = {
        "classId": int.parse(classId),
        "studentId": myStudentId
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/class-registrations'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}