import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/app_models.dart';
import '../../../core/constants/api_constants.dart';

class ClassManagementViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AppClassModel> _realClasses = [];
  List<AppClassModel> get realClasses => _realClasses;

  final Map<String, Map<String, dynamic>> _activeSessionData = {};

  // ================= JWT DECODE =================
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

  // ================= FETCH =================
  Future<void> fetchClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      // ❌ NULL TOKEN
      if (token == null || token.isEmpty) {
        throw Exception("⚠️ Chưa đăng nhập");
      }

      // 🔥 CHECK TOKEN TYPE (QUAN TRỌNG NHẤT)
      final jwtData = _decodeJwt(token);
      if (jwtData['type'] != 'access') {
        await prefs.clear();
        throw Exception("❌ Sai token → login lại");
      }

      print("ACCESS TOKEN OK");

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      };

      // ================= SESSIONS =================
      final sessionRes = await http.get(
        Uri.parse('$_baseUrl/sessions?page=0&size=50'),
        headers: headers,
      );

      if (sessionRes.statusCode == 401) {
        await prefs.clear();
        throw Exception("Token hết hạn → đăng nhập lại");
      }

      Map<String, dynamic> openSessions = {};

      if (sessionRes.statusCode == 200) {
        final data = jsonDecode(sessionRes.body);

        // 🔥 FIX JSON CHUẨN BACKEND
        final List list = data is List
            ? data
            : (data['data']?['content'] ?? data['data'] ?? []);

        for (var s in list) {
          if (s['status']?.toString().toUpperCase() == 'OPEN') {
            final classId = s['classId']?.toString();

            if (classId != null) {
              openSessions[classId] = s;

              _activeSessionData[classId] = {
                "sessionId": s['id'],
                "classId": int.tryParse(classId) ?? 0,
                "status": "OPEN",
                "locationId": s['locationId'] ?? 0,
                "startTime": s['startTime'],
                "endTime": s['endTime']
              };
            }
          }
        }
      }

      // ================= CLASS =================
      final classRes = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
        headers: headers,
      );

      if (classRes.statusCode == 401) {
        await prefs.clear();
        throw Exception("Token hết hạn → đăng nhập lại");
      }

      if (classRes.statusCode == 200) {
        final data = jsonDecode(classRes.body);

        // 🔥 FIX JSON CHUẨN BACKEND
        final List list = data is List
            ? data
            : (data['data']?['content'] ?? data['data'] ?? []);

        _realClasses = list.map((item) {
          final classId = item['id']?.toString() ?? '0';

          final savedRoom =
          prefs.getString('class_${classId}_room');
          final savedRadius =
          prefs.getDouble('class_${classId}_radius');

          return AppClassModel(
            id: classId,
            teacherId: item['teacherId']?.toString() ?? '',
            className: item['title'] ?? '',
            description: item['description'] ?? '',
            teacherName: '',
            startTime: item['startDate'] ?? '',
            endTime: item['endDate'] ?? '',
            isAttendanceOpen:
            openSessions.containsKey(classId),
            roomId: savedRoom,
            radius: savedRadius,
          );
        }).toList();
      }
    } catch (e) {
      print("FETCH ERROR: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================= DELETE =================
  Future<void> deleteClass(String classId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) return;

      final res = await http.delete(
        Uri.parse('$_baseUrl/classrooms/$classId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        _realClasses.removeWhere((c) => c.id == classId);
        notifyListeners();
      } else {
        throw Exception("Xóa thất bại");
      }
    } catch (e) {
      print("DELETE ERROR: $e");
      rethrow;
    }
  }

  // ================= UPDATE =================
  Future<void> updateClass(AppClassModel updated) async {
    try {
      int index =
      _realClasses.indexWhere((c) => c.id == updated.id);

      if (index != -1) {
        _realClasses[index] = updated;
        notifyListeners();
      }

      final prefs = await SharedPreferences.getInstance();

      if (updated.roomId != null &&
          updated.roomId!.isNotEmpty) {
        await prefs.setString(
            'class_${updated.id}_room', updated.roomId!);
      }

      if (updated.radius != null && updated.radius! > 0) {
        await prefs.setDouble(
            'class_${updated.id}_radius', updated.radius!);
      }
    } catch (e) {
      print("UPDATE ERROR: $e");
    }
  }

  // ================= TOGGLE =================
  Future<void> toggleAttendance(
      String classId, int minutes) async {
    int index =
    _realClasses.indexWhere((c) => c.id == classId);
    if (index == -1) return;

    final current = _realClasses[index];

    if (!current.isAttendanceOpen) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) return;

      final res = await http.post(
        Uri.parse('$_baseUrl/sessions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          "classId": int.parse(classId),
          "status": "OPEN"
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        _realClasses[index] =
            current.copyWith(isAttendanceOpen: true);
        notifyListeners();
      }
    }
  }
}