import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/RoomModel.dart';
import '../../../data/models/app_models.dart';
import '../../../core/constants/api_constants.dart';

class TeacherViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AppClassModel> _realClasses = [];
  List<AppClassModel> get realClasses => _realClasses;

  List<RoomModel> _realLocations = [];
  List<RoomModel> get realLocations => _realLocations;

  // ================= JWT =================
  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(resp);
    } catch (e) {
      return {};
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // ================= FETCH CLASSES =================
  Future<void> fetchClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) {
        _realClasses = [];
        return;
      }

      final jwtData = _decodeJwt(token);
      final String myTeacherId = jwtData['sub']?.toString() ?? '';

      final response = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("CLASS BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        List list = [];

        if (data is List) {
          list = data;
        } else if (data['content'] != null) {
          list = data['content'];
        } else if (data['data'] != null) {
          list = data['data']['content'] ?? data['data'];
        }

        _realClasses = list.map((item) {
          final teacherId =
              item['teacherId']?.toString() ??
                  item['teacher']?['id']?.toString() ??
                  '';

          // 🔥 FIX QUAN TRỌNG: lấy đúng classId
          final classId = item['classId']?.toString() ??
              item['id']?.toString() ??
              item['classroomId']?.toString() ??
              '';

          print("MAP CLASS -> id: $classId | teacherId: $teacherId");

          return AppClassModel(
            id: classId,
            teacherId: teacherId,
            className: item['title'] ?? item['name'] ?? '',
            description: item['description'] ?? '',
            teacherName: '',
            startTime: item['startDate'] ?? '',
            endTime: item['endDate'] ?? '',
            isAttendanceOpen: false,
          );
        }).where((c) => c.teacherId == myTeacherId && c.id.isNotEmpty).toList();
      }
    } catch (e) {
      print("FETCH CLASS ERROR: $e");
      _realClasses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================= FETCH LOCATIONS =================
  Future<void> fetchLocations() async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$_baseUrl/locations?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        List list = data['content'] ?? data['data'] ?? [];

        _realLocations = list.map((item) {
          return RoomModel(
            id: item['id']?.toString() ??
                item['locationId']?.toString() ??
                '',
            name:
            "${item['locationCode'] ?? 'Phòng'} - ${item['address'] ?? ''}",
          );
        }).toList();

        notifyListeners();
      }
    } catch (e) {
      print("LOCATION ERROR: $e");
    }
  }

  // ================= CREATE CLASS =================
  Future<bool> createClassAPI({
    required String title,
    required String description,
    required List<int> locationIds,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final token = await _getToken();
      if (token == null) return false;

      final jwtData = _decodeJwt(token);
      final int myTeacherId =
          int.tryParse(jwtData['sub']?.toString() ?? '0') ?? 0;

      final response = await http.post(
        Uri.parse('$_baseUrl/classrooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          "teacherId": myTeacherId,
          "title": title,
          "description": description,
          "startDate": DateTime.now().toIso8601String().split('T')[0],
          "endDate": DateTime.now()
              .add(const Duration(days: 90))
              .toIso8601String()
              .split('T')[0],
          "locationIds": locationIds
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchClasses();
        return true;
      }

      return false;
    } catch (e) {
      print("CREATE ERROR: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
