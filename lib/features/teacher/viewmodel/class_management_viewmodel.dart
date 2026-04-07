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
    final jwtData = _decodeJwt(token);

    if (jwtData['type'] != 'access') {
      await prefs.clear();
      return false;
    }

    final exp = jwtData['exp'];
    if (exp != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now >= exp) {
        await prefs.clear();
        return false;
      }
    }

    return true;
  }

  List _safeList(dynamic data) {
    try {
      if (data is List) return data;

      if (data is Map) {
        if (data['data'] != null) {
          if (data['data'] is Map && data['data']['content'] != null) {
            return data['data']['content'];
          }
          if (data['data'] is List) {
            return data['data'];
          }
        }

        if (data['content'] != null) {
          return data['content'];
        }
      }
    } catch (_) {}

    return [];
  }

  Future<void> fetchClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        print("❌ NO TOKEN IN CLASS MANAGEMENT");
        _realClasses = [];
        return;
      }

      final isValid = await _isTokenValid(token);
      if (!isValid) {
        print("❌ TOKEN INVALID IN CLASS MANAGEMENT");
        _realClasses = [];
        return;
      }

      final jwtData = _decodeJwt(token);
      final myTeacherId = jwtData['sub']?.toString() ?? '';

      print("✅ ACCESS TOKEN OK");
      print("MY TEACHER ID: $myTeacherId");

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      _activeSessionData.clear();

      final sessionRes = await http.get(
        Uri.parse('$_baseUrl/sessions?page=0&size=50'),
        headers: headers,
      );

      print("SESSION STATUS: ${sessionRes.statusCode}");
      print("SESSION BODY: ${sessionRes.body}");

      final Map<String, dynamic> openSessions = {};

      if (sessionRes.statusCode == 200) {
        final data = jsonDecode(utf8.decode(sessionRes.bodyBytes));
        final List list = _safeList(data);

        print("SESSION LIST LENGTH: ${list.length}");

        for (var s in list) {
          final status = s['status']?.toString().toUpperCase();

          if (status == 'OPEN' ||
              status == '1' ||
              status == 'ACTIVE' ||
              status == 'ONGOING') {
            final classId =
                s['classroomId']?.toString() ??
                    s['classRoomId']?.toString() ??
                    s['classId']?.toString() ??
                    s['classroom']?['id']?.toString() ??
                    s['classroom']?['classId']?.toString() ??
                    s['classRoom']?['id']?.toString() ??
                    s['classRoom']?['classId']?.toString();

            if (classId != null && classId.isNotEmpty) {
              openSessions[classId] = s;

              _activeSessionData[classId] = {
                "sessionId": s['id'],
                "classId": int.tryParse(classId) ?? 0,
                "status": status,
                "locationId":
                s['locationId'] ??
                    s['location']?['id'] ??
                    s['classRoom']?['locationId'] ??
                    s['classroom']?['locationId'] ??
                    0,
                "startTime": s['startTime'],
                "endTime": s['endTime'],
              };
            }
          }
        }
      }

      final classRes = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
        headers: headers,
      );

      print("CLASS STATUS: ${classRes.statusCode}");
      print("CLASS BODY: ${classRes.body}");

      if (classRes.statusCode == 401) {
        await prefs.clear();
        _realClasses = [];
        return;
      }

      if (classRes.statusCode == 200) {
        final data = jsonDecode(utf8.decode(classRes.bodyBytes));
        final List list = _safeList(data);

        print("CLASS LIST LENGTH: ${list.length}");

        final mappedClasses = list.map((item) {
          final classId = (item['id'] ?? item['classId']).toString();

          final teacherId =
              item['teacherId']?.toString() ??
                  item['teacher']?['id']?.toString() ??
                  '';

          final isOpen = openSessions.containsKey(classId);

          final locationIds = item['locationIds'];

          // Ưu tiên location đã set local, nếu chưa có thì mới lấy từ backend
          final localRoomId = prefs.getString('class_${classId}_room');

          String? roomId;
          if (localRoomId != null && localRoomId.isNotEmpty) {
            roomId = localRoomId;
          } else if (locationIds is List && locationIds.isNotEmpty) {
            roomId = locationIds.first.toString();
          }

          final localRadius = prefs.getDouble('class_${classId}_radius');

          return AppClassModel(
            id: classId,
            teacherId: teacherId,
            className: item['title'] ?? item['name'] ?? '',
            description: item['description'] ?? '',
            teacherName: item['teacherName'] ?? '',
            startTime: item['startDate']?.toString() ?? '',
            endTime: item['endDate']?.toString() ?? '',
            isAttendanceOpen: isOpen,
            roomId: roomId,
            radius: localRadius,
          );
        }).toList();

        _realClasses = mappedClasses.where((c) {
          return c.teacherId.toString() == myTeacherId;
        }).toList();

        print("FINAL REAL CLASSES LENGTH: ${_realClasses.length}");
      } else {
        print("❌ CLASS API ERROR: ${classRes.statusCode}");
        _realClasses = [];
      }
    } catch (e) {
      print("FETCH ERROR: $e");
      _realClasses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteClass(String classId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) return;

      final res = await http.delete(
        Uri.parse('$_baseUrl/classrooms/$classId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        _realClasses.removeWhere((c) => c.id == classId);

        await prefs.remove('class_${classId}_room');
        await prefs.remove('class_${classId}_radius');

        notifyListeners();
      }
    } catch (e) {
      print("DELETE ERROR: $e");
    }
  }

  Future<void> updateClass(AppClassModel updated) async {
    try {
      final index = _realClasses.indexWhere((c) => c.id == updated.id);

      if (index != -1) {
        _realClasses[index] = updated;
        notifyListeners();
      }

      final prefs = await SharedPreferences.getInstance();

      if (updated.roomId != null && updated.roomId!.isNotEmpty) {
        await prefs.setString('class_${updated.id}_room', updated.roomId!);
      }

      if (updated.radius != null && updated.radius! > 0) {
        await prefs.setDouble('class_${updated.id}_radius', updated.radius!);
      }
    } catch (e) {
      print("UPDATE ERROR: $e");
    }
  }

  Future<void> toggleAttendance(String classId, int minutes) async {
    final index = _realClasses.indexWhere((c) => c.id == classId);
    if (index == -1) return;

    final current = _realClasses[index];
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      throw Exception("Không tìm thấy token");
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    if (!current.isAttendanceOpen) {
      final now = DateTime.now();
      final end = now.add(Duration(minutes: minutes));

      final locationId = int.tryParse(current.roomId ?? '');
      if (locationId == null) {
        throw Exception("Lớp chưa có locationId. Hãy Set Location trước.");
      }

      final body = {
        "title": "Attendance - ${current.className}",
        "startTime": now.toIso8601String(),
        "endTime": end.toIso8601String(),
        "status": "OPEN",
        "classId": int.parse(classId),
        "locationId": locationId,
      };

      print("OPEN SESSION BODY: ${jsonEncode(body)}");

      final res = await http.post(
        Uri.parse('$_baseUrl/sessions'),
        headers: headers,
        body: jsonEncode(body),
      );

      print("TOGGLE SESSION STATUS: ${res.statusCode}");
      print("TOGGLE SESSION BODY: ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchClasses();
      } else {
        throw Exception("Mở điểm danh thất bại");
      }
    } else {
      throw Exception("Chức năng đóng điểm danh chưa được backend hỗ trợ");
    }
  }
}