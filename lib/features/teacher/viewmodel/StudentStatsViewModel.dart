import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';

class StudentStatsModel {
  final String studentId;
  final String studentName;
  final int present;
  final int absent;
  final double percent;

  StudentStatsModel({
    required this.studentId,
    required this.studentName,
    required this.present,
    required this.absent,
    required this.percent,
  });
}

class StudentStatsViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<StudentStatsModel> _statsList = [];
  List<StudentStatsModel> get statsList => _statsList;

  int _totalStudents = 0;
  int get totalStudents => _totalStudents;

  String _avgAttendance = '0%';
  String get avgAttendance => _avgAttendance;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ??
        prefs.getString('token') ??
        prefs.getString('jwt') ??
        prefs.getString('accessToken');
  }

  List<dynamic> _safeList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      if (data['content'] is List) return data['content'];
      if (data['data'] is List) return data['data'];
      if (data['result'] is List) return data['result'];
      if (data['items'] is List) return data['items'];
      if (data['data'] is Map && data['data']['content'] is List) {
        return data['data']['content'];
      }
      if (data['result'] is Map && data['result']['content'] is List) {
        return data['result']['content'];
      }
    }
    return [];
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  Future<void> fetchClassStats(String classId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        _errorMessage = 'Không tìm thấy token. Vui lòng đăng nhập lại.';
        _clearData();
        return;
      }

      final id = classId.trim();
      if (id.isEmpty || id == '0') {
        _errorMessage = 'Không xác định được mã lớp.';
        _clearData();
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/attendance/class/$id/student-stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      debugPrint('STUDENT STATS STATUS -> ${response.statusCode}');
      debugPrint('STUDENT STATS BODY -> ${utf8.decode(response.bodyBytes)}');

      if (response.statusCode == 401 || response.statusCode == 403) {
        _errorMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        _clearData();
        return;
      }

      if (response.statusCode != 200) {
        _errorMessage = 'Không tải được thống kê điểm danh.';
        _clearData();
        return;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final list = _safeList(decoded);

      final mapped = <StudentStatsModel>[];

      for (final raw in list) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);

        final studentId = _text(
          item['studentId'] ??
              item['userId'] ??
              item['id'] ??
              item['studentCode'],
        );

        if (studentId.isEmpty) continue;

        final studentName = _text(
          item['studentName'] ??
              item['userName'] ??
              item['fullName'] ??
              item['name'] ??
              item['username'],
        );

        final present = _parseInt(
          item['present'] ??
              item['presentCount'] ??
              item['totalPresent'] ??
              item['attendedSessions'],
        );

        final absent = _parseInt(
          item['absent'] ??
              item['absentCount'] ??
              item['totalAbsent'] ??
              item['missedSessions'],
        );

        final total = present + absent;

        double percent = _parseDouble(
          item['percent'] ??
              item['attendancePercent'] ??
              item['percentage'] ??
              item['attendanceRate'],
        );

        if (total > 0) {
          percent = present / total * 100;
        }

        mapped.add(
          StudentStatsModel(
            studentId: studentId,
            studentName:
            studentName.isNotEmpty ? studentName : 'Sinh viên $studentId',
            present: present,
            absent: absent,
            percent: percent.clamp(0.0, 100.0),
          ),
        );
      }

      mapped.sort((a, b) => a.studentName.compareTo(b.studentName));

      _statsList = mapped;
      _totalStudents = mapped.length;

      if (mapped.isEmpty) {
        _avgAttendance = '0%';
      } else {
        final avg = mapped.fold<double>(
          0.0,
              (sum, item) => sum + item.percent,
        ) /
            mapped.length;

        _avgAttendance = '${avg.toStringAsFixed(0)}%';
      }
    } catch (e) {
      debugPrint('FETCH CLASS STATS ERROR -> $e');
      _errorMessage = 'Lỗi tải thống kê.';
      _clearData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> downloadExcel(String classId) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return;

      final id = classId.trim();
      if (id.isEmpty || id == '0') return;

      final uri = Uri.parse('$_baseUrl/attendance/class/$id/export');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('DOWNLOAD EXCEL ERROR -> $e');
    }
  }

  void _clearData() {
    _statsList = [];
    _totalStudents = 0;
    _avgAttendance = '0%';
  }
}