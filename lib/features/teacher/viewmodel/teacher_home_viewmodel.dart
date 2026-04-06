import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';

class TeacherHomeViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int totalClasses = 0;
  int openClasses = 0;

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final payload = token.split('.')[1];
      return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))));
    } catch(e) { return {}; }
  }

  Future<void> fetchDashboardData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final jwtData = _decodeJwt(token!);
      final String myTeacherId = jwtData['sub']?.toString() ?? '';

      final classResponse = await http.get(
          Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
          headers: {'Authorization': 'Bearer $token'});
      final sessionResponse = await http.get(
          Uri.parse('$_baseUrl/sessions?page=0&size=50'),
          headers: {'Authorization': 'Bearer $token'});

      if (classResponse.statusCode == 200) {
        final classData = jsonDecode(utf8.decode(classResponse.bodyBytes));
        final List<dynamic> classContent = classData is List
            ? classData
            : (classData['content'] ?? classData['data'] ?? []);

        final myClasses = classContent.where((item) =>
        item['teacherId']?.toString() == myTeacherId).toList();
        totalClasses = myClasses.length;

        List<String> myClassIds = myClasses.map((c) =>
            (c['id'] ?? c['classId']).toString()).toList();

        // 🔥 ĐÃ SỬA: Dùng Set để chứa ID Lớp. Nếu 1 lớp có 10 phiên mở, Set cũng chỉ tính là 1 Lớp!
        Set<String> uniqueOpenClasses = {};

        if (sessionResponse.statusCode == 200) {
          final sessionData = jsonDecode(
              utf8.decode(sessionResponse.bodyBytes));
          final List<dynamic> sessionContent = sessionData is List
              ? sessionData
              : (sessionData['content'] ?? sessionData['data'] ?? []);

          for (var session in sessionContent) {
            final status = session['status']?.toString().toUpperCase();
            if (status == 'OPEN' || status == '1') {
              final sClassId = session['classroomId']?.toString() ??
                  session['classRoomId']?.toString() ??
                  session['classId']?.toString() ??
                  session['classRoom']?['id']?.toString() ??
                  session['classRoom']?['classId']?.toString();

              if (sClassId != null && myClassIds.contains(sClassId)) {
                // Nhét ID lớp vào Set. (Đặc tính của Set là tự động loại bỏ trùng lặp)
                uniqueOpenClasses.add(sClassId);
              }
            }
          }
        }

        // Gán số lượng lớp đang mở bằng đúng số phần tử trong Set
        openClasses = uniqueOpenClasses.length;
      }
    } catch (e) {
      print("LỖI DATA DASHBOARD: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}