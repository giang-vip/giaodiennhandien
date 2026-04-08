import 'dart:convert';
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

  String _normalizeText(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> fetchClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        print(" NO TOKEN IN CLASS MANAGEMENT");
        _realClasses = [];
        return;
      }

      final isValid = await _isTokenValid(token);
      if (!isValid) {
        print("TOKEN INVALID IN CLASS MANAGEMENT");
        _realClasses = [];
        return;
      }

      final jwtData = _decodeJwt(token);
      final myTeacherId = jwtData['sub']?.toString() ?? '';

      print(" ACCESS TOKEN OK");
      print("MY TEACHER ID: $myTeacherId");

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      _activeSessionData.clear();

      // 1) Lấy class trước
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

      if (classRes.statusCode != 200) {
        print(" CLASS API ERROR: ${classRes.statusCode}");
        _realClasses = [];
        return;
      }

      final classData = jsonDecode(utf8.decode(classRes.bodyBytes));
      final List classList = _safeList(classData);

      print("CLASS LIST LENGTH: ${classList.length}");

      final mappedClasses = classList.map((item) {
        final classId = (item['id'] ?? item['classId']).toString();

        final teacherId =
            item['teacherId']?.toString() ??
                item['teacher']?['id']?.toString() ??
                '';

        final locationIds = item['locationIds'];
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
          isAttendanceOpen: false,
          roomId: roomId,
          radius: localRadius,
        );
      }).toList();

      _realClasses = mappedClasses.where((c) {
        return c.teacherId.toString() == myTeacherId;
      }).toList();

      // 2) Lấy sessions sau
      final sessionRes = await http.get(
        Uri.parse('$_baseUrl/sessions'),
        headers: headers,
      );

      print("SESSION STATUS: ${sessionRes.statusCode}");
      print("SESSION BODY: ${sessionRes.body}");

      if (sessionRes.statusCode == 200) {
        final sessionData = jsonDecode(utf8.decode(sessionRes.bodyBytes));
        final List sessionList = _safeList(sessionData);

        print("SESSION LIST LENGTH: ${sessionList.length}");

        for (var s in sessionList) {
          final status = s['status']?.toString().toUpperCase();

          if (status != 'OPEN' &&
              status != '1' &&
              status != 'ACTIVE' &&
              status != 'ONGOING') {
            continue;
          }

          String? classId =
              s['classroomId']?.toString() ??
                  s['classRoomId']?.toString() ??
                  s['classId']?.toString() ??
                  s['classroom']?['id']?.toString() ??
                  s['classroom']?['classId']?.toString() ??
                  s['classRoom']?['id']?.toString() ??
                  s['classRoom']?['classId']?.toString();

          final sessionTitle = _normalizeText((s['title'] ?? '').toString());
          final sessionLocationId = (s['locationId'] ?? '').toString();

          // fallback 1: match theo title
          if (classId == null || classId.isEmpty) {
            for (final c in _realClasses) {
              final expectedTitle =
              _normalizeText("Attendance - ${c.className}");
              if (sessionTitle == expectedTitle) {
                classId = c.id;
                break;
              }
            }
          }

          // fallback 2: match theo locationId nếu chỉ có 1 lớp khớp
          if ((classId == null || classId.isEmpty) &&
              sessionLocationId.isNotEmpty) {
            final candidates = _realClasses.where((c) {
              return (c.roomId ?? '') == sessionLocationId;
            }).toList();

            if (candidates.length == 1) {
              classId = candidates.first.id;
            }
          }

          if (classId != null && classId.isNotEmpty) {
            _activeSessionData[classId] = {
              "sessionId": s['sessionId'] ?? s['id'],
              "classId": int.tryParse(classId) ?? 0,
              "status": status,
              "locationId": s['locationId'] ?? 0,
              "startTime": s['startTime'],
              "endTime": s['endTime'],
              "title": s['title'],
            };

            final index = _realClasses.indexWhere((c) => c.id == classId);
            if (index != -1) {
              final old = _realClasses[index];
              _realClasses[index] = old.copyWith(isAttendanceOpen: true);
            }

            print("MATCHED OPEN SESSION -> classId=$classId, sessionId=${s['sessionId'] ?? s['id']}");
          } else {
            print("UNMATCHED OPEN SESSION: ${jsonEncode(s)}");
          }
        }
      }

      print("FINAL REAL CLASSES LENGTH: ${_realClasses.length}");
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

      if (token == null || token.isEmpty) {
        throw Exception("Không tìm thấy token");
      }

      final res = await http.delete(
        Uri.parse('$_baseUrl/classrooms/$classId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print("DELETE CLASS STATUS: ${res.statusCode}");
      print("DELETE CLASS RESPONSE: ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 204) {
        _realClasses.removeWhere((c) => c.id == classId);
        await prefs.remove('class_${classId}_room');
        await prefs.remove('class_${classId}_radius');
        notifyListeners();
      } else {
        throw Exception("Xóa lớp thất bại: ${res.body}");
      }
    } catch (e) {
      print("DELETE ERROR: $e");
      rethrow;
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

      await fetchClasses();
    } catch (e) {
      print("UPDATE ERROR: $e");
      rethrow;
    }
  }

  Future<void> toggleAttendance(String classId, int minutes) async {
    final index = _realClasses.indexWhere((c) => c.id == classId);
    if (index == -1) {
      throw Exception("Không tìm thấy lớp");
    }

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
      if (locationId == null || locationId <= 0) {
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

      print("========== OPEN SESSION ==========");
      print("URL: $_baseUrl/sessions");
      print("BODY: ${jsonEncode(body)}");

      final res = await http.post(
        Uri.parse('$_baseUrl/sessions'),
        headers: headers,
        body: jsonEncode(body),
      );

      print("OPEN SESSION STATUS: ${res.statusCode}");
      print("OPEN SESSION RESPONSE: ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchClasses();
      } else if (res.statusCode == 403) {
        throw Exception("403 Forbidden - tài khoản không có quyền mở điểm danh");
      } else if (res.statusCode == 401) {
        throw Exception("401 Unauthorized - token không hợp lệ");
      } else {
        throw Exception("Mở điểm danh thất bại: ${res.body}");
      }
    } else {
      Map<String, dynamic>? sessionData = _activeSessionData[classId];

      // fallback tìm theo title nếu không có đúng classId
      if (sessionData == null) {
        final expectedTitle =
        _normalizeText("Attendance - ${current.className}");

        for (final entry in _activeSessionData.entries) {
          final title = _normalizeText(
            (entry.value['title'] ?? '').toString(),
          );
          if (title == expectedTitle) {
            sessionData = entry.value;
            print("FOUND SESSION BY TITLE FOR CLOSE: ${jsonEncode(sessionData)}");
            break;
          }
        }
      }

      // fallback tìm theo location nếu vẫn chưa thấy
      if (sessionData == null && (current.roomId ?? '').isNotEmpty) {
        for (final entry in _activeSessionData.entries) {
          final locId = (entry.value['locationId'] ?? '').toString();
          if (locId == current.roomId.toString()) {
            sessionData = entry.value;
            print("FOUND SESSION BY LOCATION FOR CLOSE: ${jsonEncode(sessionData)}");
            break;
          }
        }
      }

      if (sessionData == null) {
        print("ACTIVE SESSION MAP: ${jsonEncode(_activeSessionData)}");
        throw Exception("Không tìm thấy session đang mở");
      }

      final sessionId = sessionData['sessionId'];
      if (sessionId == null) {
        throw Exception("Session đang mở không có sessionId");
      }

      int locationId = int.tryParse(current.roomId ?? '') ?? 0;
      if (locationId <= 0) {
        final rawLocationId = sessionData['locationId'];
        if (rawLocationId != null) {
          locationId = int.tryParse(rawLocationId.toString()) ?? 0;
        }
      }

      if (locationId <= 0) {
        throw Exception("Không tìm thấy locationId để đóng điểm danh");
      }

      final body = {
        "title": sessionData['title'] ?? "Attendance - ${current.className}",
        "startTime":
        sessionData['startTime'] ?? DateTime.now().toIso8601String(),
        "endTime": DateTime.now().toIso8601String(),
        "status": "CLOSED",
        "classId": int.parse(classId),
        "locationId": locationId,
      };

      print("========== CLOSE SESSION ==========");
      print("URL: $_baseUrl/sessions/$sessionId");
      print("BODY: ${jsonEncode(body)}");

      final res = await http.put(
        Uri.parse('$_baseUrl/sessions/$sessionId'),
        headers: headers,
        body: jsonEncode(body),
      );

      print("CLOSE SESSION STATUS: ${res.statusCode}");
      print("CLOSE SESSION RESPONSE: ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchClasses();
      } else {
        throw Exception("Đóng điểm danh thất bại: ${res.body}");
      }
    }
  }
}