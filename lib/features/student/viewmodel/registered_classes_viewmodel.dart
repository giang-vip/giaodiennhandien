import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/app_models.dart';

class RegisteredClassesViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AppClassModel> _registeredClasses = [];
  List<AppClassModel> get registeredClasses => _registeredClasses;

  Map<String, int> _activeSessions = {};

  // 🔥 1. THÊM: Map lưu trữ locationId của phiên điểm danh đang mở
  Map<String, int> _sessionLocations = {};

  bool isClassActive(String classId) => _activeSessions.containsKey(classId);
  int? getActiveSessionId(String classId) => _activeSessions[classId];

  // 🔥 2. THÊM: Hàm lấy locationId
  int? getSessionLocationId(String classId) => _sessionLocations[classId];

  int _getMyStudentId(String token) {
    try {
      final payload = token.split('.')[1];
      final decoded = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))));
      return int.parse(decoded['sub'].toString());
    } catch (e) {
      return 0;
    }
  }

  Future<void> fetchRegisteredClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final myStudentId = _getMyStudentId(token!);

      // BƯỚC 1: Lấy danh sách ID đã đăng ký
      final myRegResponse = await http.get(
        Uri.parse('$_baseUrl/class-registrations/student/$myStudentId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      Set<String> registeredIds = {};
      if (myRegResponse.statusCode == 200) {
        final rawRegData = jsonDecode(utf8.decode(myRegResponse.bodyBytes));
        // 🔥 ĐÃ SỬA: Chống Crash JSON
        final List<dynamic> myRegData = rawRegData is List ? rawRegData : (rawRegData['content'] ?? rawRegData['data'] ?? []);

        for (var item in myRegData) {
          final cId = item['classId']?.toString() ?? item['classRoom']?['classId']?.toString() ?? '0';
          registeredIds.add(cId);
        }
      }

      // BƯỚC 2: Tải thông tin lớp học và lọc lớp đã đăng ký
      final classResponse = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (classResponse.statusCode == 200) {
        final data = jsonDecode(utf8.decode(classResponse.bodyBytes));
        // 🔥 ĐÃ SỬA: Chống Crash JSON
        final List<dynamic> classContent = data is List ? data : (data['content'] ?? data['data'] ?? []);

        _registeredClasses = classContent.where((item) {
          final checkId = item['classId']?.toString() ?? item['id']?.toString() ?? '0';
          return registeredIds.contains(checkId);
        }).map((item) => AppClassModel(
          id: item['classId']?.toString() ?? item['id']?.toString() ?? '0',
          teacherId: item['teacherId']?.toString() ?? '0',
          className: item['title'] ?? 'Chưa có tên',
          description: item['description'] ?? 'Chưa có mô tả',
          teacherName: item['teacherName'] ?? 'Giảng viên',
          startTime: item['startDate'] ?? 'N/A',
          endTime: item['endDate'] ?? 'N/A',
        )).toList();
      }

      // BƯỚC 3: Quét phiên điểm danh đang mở
      final sessionResponse = await http.get(
        Uri.parse('$_baseUrl/sessions?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      _activeSessions.clear();
      _sessionLocations.clear(); // 🔥 THÊM: Clear dữ liệu cũ

      if (sessionResponse.statusCode == 200) {
        final sessionData = jsonDecode(utf8.decode(sessionResponse.bodyBytes));
        // 🔥 ĐÃ SỬA: Chống Crash JSON
        final List<dynamic> content = sessionData is List ? sessionData : (sessionData['content'] ?? sessionData['data'] ?? []);

        for (var session in content) {
          final status = session['status']?.toString().toUpperCase();
          if (status == 'OPEN' || status == '1') {
            // 🔥 ĐÃ SỬA: Quét ID thông minh giống bên Giáo viên
            final sClassId = session['classroomId']?.toString() ??
                session['classRoomId']?.toString() ??
                session['classId']?.toString() ??
                session['classRoom']?['id']?.toString() ??
                session['classRoom']?['classId']?.toString();

            final sId = session['sessionId'] ?? session['id'];
            final locId = session['locationId']; // 🔥 THÊM: Đọc locationId từ API

            if (sClassId != null && sId != null && sClassId != 'null') {
              _activeSessions[sClassId] = sId;

              // 🔥 THÊM: Lưu locationId lại nếu có
              if (locId != null) {
                _sessionLocations[sClassId] = int.tryParse(locId.toString()) ?? 0;
              }
            }
          }
        }
      }
    } catch (e) {
      print("❌ LỖI MY CLASSES: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}