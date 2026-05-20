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
  int totalStudents = 0;
  String teacherName = 'Giáo viên';
  String teacherEmail = '';

  List<Map<String, dynamic>> teacherClasses = [];

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

  List<dynamic> _safeList(dynamic data) {
    try {
      if (data is List) return data;

      if (data is Map) {
        if (data['data'] != null) {
          if (data['data'] is Map && data['data']['content'] != null) {
            return List<dynamic>.from(data['data']['content']);
          }
          if (data['data'] is List) {
            return List<dynamic>.from(data['data']);
          }
        }

        if (data['content'] != null) {
          return List<dynamic>.from(data['content']);
        }
      }
    } catch (_) {}

    return [];
  }

  bool _isOpenStatus(dynamic status) {
    final value = status?.toString().toUpperCase() ?? '';
    return value == 'OPEN' ||
        value == '1' ||
        value == 'ACTIVE' ||
        value == 'ONGOING';
  }

  String _extractClassId(Map item) {
    return (item['id'] ?? item['classId'] ?? '').toString();
  }

  String? _extractSessionClassId(Map session) {
    return session['classroomId']?.toString() ??
        session['classRoomId']?.toString() ??
        session['classId']?.toString() ??
        session['classRoom']?['id']?.toString() ??
        session['classRoom']?['classId']?.toString() ??
        session['classroom']?['id']?.toString() ??
        session['classroom']?['classId']?.toString();
  }

  int _calculateTotalStudents(List<Map<String, dynamic>> classes) {
    int total = 0;
    for (var classItem in classes) {
      total += classItem['studentCount'] as int? ?? 0;
    }
    return total;
  }

  Future<void> fetchDashboardData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        totalClasses = 0;
        openClasses = 0;
        totalStudents = 0;
        teacherClasses = [];
        teacherName = 'Giáo viên';
        return;
      }

      final isValid = await _isTokenValid(token);
      if (!isValid) {
        totalClasses = 0;
        openClasses = 0;
        totalStudents = 0;
        teacherClasses = [];
        teacherName = 'Giáo viên';
        return;
      }

      final jwtData = _decodeJwt(token);
      final String myTeacherId = jwtData['sub']?.toString() ?? '';
      teacherName =
          jwtData['username']?.toString() ??
              jwtData['fullName']?.toString() ??
              jwtData['name']?.toString() ??
              'Giáo viên';
      teacherEmail = jwtData['email']?.toString() ?? '';

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final classResponse = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=100'),
        headers: headers,
      );

      final sessionResponse = await http.get(
        Uri.parse('$_baseUrl/sessions?page=0&size=100'),
        headers: headers,
      );

      if (classResponse.statusCode == 401) {
        await prefs.clear();
        totalClasses = 0;
        openClasses = 0;
        totalStudents = 0;
        teacherClasses = [];
        return;
      }

      if (classResponse.statusCode == 200) {
        final classData = jsonDecode(utf8.decode(classResponse.bodyBytes));
        final List<dynamic> classContent = _safeList(classData);

        final myClasses = classContent.where((item) {
          return item is Map &&
              item['teacherId']?.toString() == myTeacherId;
        }).map((e) => Map<String, dynamic>.from(e as Map)).toList();

        totalClasses = myClasses.length;

        final List<String> myClassIds =
        myClasses.map((c) => _extractClassId(c)).toList();

        final Set<String> uniqueOpenClasses = {};

        if (sessionResponse.statusCode == 200) {
          final sessionData = jsonDecode(utf8.decode(sessionResponse.bodyBytes));
          final List<dynamic> sessionContent = _safeList(sessionData);

          for (var raw in sessionContent) {
            if (raw is! Map) continue;
            final session = Map<String, dynamic>.from(raw);

            if (_isOpenStatus(session['status'])) {
              final sClassId = _extractSessionClassId(session);
              if (sClassId != null && myClassIds.contains(sClassId)) {
                uniqueOpenClasses.add(sClassId);
              }
            }
          }

          openClasses = uniqueOpenClasses.length;
        } else {
          openClasses = 0;
        }

        teacherClasses = myClasses.map((item) {
          final classId = _extractClassId(item);
          return {
            'id': classId,
            'title': item['title'] ?? 'Chưa có tên lớp',
            'description': item['description'] ?? '',
            'startDate': item['startDate']?.toString() ?? 'N/A',
            'endDate': item['endDate']?.toString() ?? 'N/A',
            'studentCount': item['studentCount'] as int? ?? 0,
            'maxStudents': item['maxStudents'] as int? ?? 0,
            'isOpen': uniqueOpenClasses.contains(classId),
          };
        }).toList();

        teacherClasses.sort((a, b) {
          final aOpen = a['isOpen'] == true ? 1 : 0;
          final bOpen = b['isOpen'] == true ? 1 : 0;
          return bOpen.compareTo(aOpen);
        });

        totalStudents = _calculateTotalStudents(teacherClasses);
      } else {
        totalClasses = 0;
        openClasses = 0;
        totalStudents = 0;
        teacherClasses = [];
      }
    } catch (e) {
      totalClasses = 0;
      openClasses = 0;
      totalStudents = 0;
      teacherClasses = [];
      teacherName = 'Giáo viên';
      debugPrint('[v0] LỖI DATA DASHBOARD: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}