import 'dart:async';
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
  final Map<String, Timer> _attendanceTimers = {};
  final Set<String> _closingClassIds = {};

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

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  bool _isOpenStatus(dynamic status) {
    final s = status?.toString().toUpperCase().trim() ?? '';
    return s == 'OPEN' || s == '1' || s == 'ACTIVE' || s == 'ONGOING';
  }

  int _calculateAttendanceMinutes(dynamic startTime, dynamic endTime) {
    final start = _parseDateTime(startTime);
    final end = _parseDateTime(endTime);

    if (start == null || end == null) return 0;

    final minutes = end.difference(start).inMinutes;
    return minutes > 0 ? minutes : 0;
  }

  void _cancelTimer(String classId) {
    _attendanceTimers[classId]?.cancel();
    _attendanceTimers.remove(classId);
  }

  void _cancelAllTimers() {
    for (final timer in _attendanceTimers.values) {
      timer.cancel();
    }
    _attendanceTimers.clear();
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      throw Exception("Không tìm thấy token");
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<void> fetchClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        print("NO TOKEN IN CLASS MANAGEMENT");
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

      print("ACCESS TOKEN OK");
      print("MY TEACHER ID: $myTeacherId");

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      _activeSessionData.clear();
      _cancelAllTimers();

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
        print("CLASS API ERROR: ${classRes.statusCode}");
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
          attendanceDuration: 0,
          roomId: roomId,
          radius: localRadius,
          attendanceStartTime: null,
          attendanceEndTime: null,
        );
      }).toList();

      _realClasses = mappedClasses.where((c) {
        return c.teacherId.toString() == myTeacherId;
      }).toList();

      final sessionRes = await http.get(
        Uri.parse('$_baseUrl/sessions'),
        headers: headers,
      );

      print("SESSION STATUS: ${sessionRes.statusCode}");
      print("SESSION BODY: ${sessionRes.body}");

      final List<String> expiredClassIds = [];

      if (sessionRes.statusCode == 200) {
        final sessionData = jsonDecode(utf8.decode(sessionRes.bodyBytes));
        final List sessionList = _safeList(sessionData);

        print("SESSION LIST LENGTH: ${sessionList.length}");

        for (var s in sessionList) {
          final status = s['status'];

          if (!_isOpenStatus(status)) {
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

          if (classId == null || classId.isEmpty) {
            for (final c in _realClasses) {
              final expectedTitle = _normalizeText("Attendance - ${c.className}");
              if (sessionTitle == expectedTitle) {
                classId = c.id;
                break;
              }
            }
          }

          if ((classId == null || classId.isEmpty) &&
              sessionLocationId.isNotEmpty) {
            final candidates = _realClasses.where((c) {
              return (c.roomId ?? '') == sessionLocationId;
            }).toList();

            if (candidates.length == 1) {
              classId = candidates.first.id;
            }
          }

          if (classId == null || classId.isEmpty) {
            print("UNMATCHED OPEN SESSION: ${jsonEncode(s)}");
            continue;
          }

          final sessionEnd = _parseDateTime(s['endTime']);
          final isExpired =
              sessionEnd != null && !sessionEnd.isAfter(DateTime.now());

          _activeSessionData[classId] = {
            "sessionId": s['sessionId'] ?? s['id'],
            "classId": int.tryParse(classId) ?? 0,
            "status": s['status'],
            "locationId": s['locationId'] ?? 0,
            "startTime": s['startTime'],
            "endTime": s['endTime'],
            "title": s['title'],
          };

          final index = _realClasses.indexWhere((c) => c.id == classId);
          if (index != -1) {
            final old = _realClasses[index];

            _realClasses[index] = old.copyWith(
              isAttendanceOpen: !isExpired,
              attendanceDuration: _calculateAttendanceMinutes(
                s['startTime'],
                s['endTime'],
              ),
              attendanceStartTime: s['startTime']?.toString(),
              attendanceEndTime: s['endTime']?.toString(),
            );
          }

          if (isExpired) {
            expiredClassIds.add(classId);
            print("SESSION EXPIRED -> classId=$classId");
          } else {
            print(
              "MATCHED OPEN SESSION -> classId=$classId, sessionId=${s['sessionId'] ?? s['id']}",
            );
          }
        }
      }

      for (final c in _realClasses) {
        if (c.isAttendanceOpen) {
          _scheduleAutoClose(c.id);
        }
      }

      print("FINAL REAL CLASSES LENGTH: ${_realClasses.length}");

      for (final classId in expiredClassIds) {
        _closeExpiredSession(classId);
      }
    } catch (e) {
      print("FETCH ERROR: $e");
      _realClasses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _scheduleAutoClose(String classId) {
    _cancelTimer(classId);

    final classModel = _realClasses.cast<AppClassModel?>().firstWhere(
          (c) => c?.id == classId,
      orElse: () => null,
    );

    if (classModel == null || !classModel.isAttendanceOpen) {
      return;
    }

    final endTime = classModel.attendanceEndDateTime;
    if (endTime == null) {
      return;
    }

    final remain = endTime.difference(DateTime.now());

    if (remain.inSeconds <= 0) {
      _closeExpiredSession(classId);
      return;
    }

    _attendanceTimers[classId] = Timer(remain, () async {
      await _closeExpiredSession(classId);
    });
  }

  Future<void> _closeExpiredSession(String classId) async {
    if (_closingClassIds.contains(classId)) return;
    _closingClassIds.add(classId);

    try {
      final sessionData = _activeSessionData[classId];
      if (sessionData == null) {
        return;
      }

      final currentIndex = _realClasses.indexWhere((c) => c.id == classId);
      if (currentIndex == -1) {
        return;
      }

      final current = _realClasses[currentIndex];
      await _closeSessionInternal(
        classId: classId,
        current: current,
        sessionData: sessionData,
        silentRefresh: true,
      );

      await fetchClasses();
    } catch (e) {
      print("AUTO CLOSE ERROR: $e");
    } finally {
      _closingClassIds.remove(classId);
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
        _cancelTimer(classId);
        _activeSessionData.remove(classId);
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
        _realClasses[index] = current.copyWith(
          isAttendanceOpen: true,
          attendanceDuration: minutes,
          attendanceStartTime: now.toIso8601String(),
          attendanceEndTime: end.toIso8601String(),
        );
        notifyListeners();

        _scheduleAutoClose(classId);
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

      await _closeSessionInternal(
        classId: classId,
        current: current,
        sessionData: sessionData,
      );
    }
  }

  Future<void> _closeSessionInternal({
    required String classId,
    required AppClassModel current,
    required Map<String, dynamic> sessionData,
    bool silentRefresh = false,
  }) async {
    final headers = await _getHeaders();

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
      _cancelTimer(classId);
      _activeSessionData.remove(classId);

      final index = _realClasses.indexWhere((c) => c.id == classId);
      if (index != -1) {
        _realClasses[index] = _realClasses[index].copyWith(
          isAttendanceOpen: false,
          attendanceDuration: 0,
          attendanceStartTime: null,
          attendanceEndTime: null,
        );
        notifyListeners();
      }

      if (!silentRefresh) {
        await fetchClasses();
      }
    } else {
      throw Exception("Đóng điểm danh thất bại: ${res.body}");
    }
  }

  String getRemainingTimeText(AppClassModel classModel) {
    final remain = classModel.remainingAttendanceTime;

    if (!classModel.isAttendanceOpen) return "Đã đóng";
    if (remain == null) return "Không rõ thời gian";
    if (remain == Duration.zero) return "Đã hết giờ";

    final hours = remain.inHours;
    final minutes = remain.inMinutes.remainder(60);
    final seconds = remain.inSeconds.remainder(60);

    if (hours > 0) {
      return "${hours}h ${minutes}m ${seconds}s";
    }
    return "${minutes}m ${seconds}s";
  }

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }
}