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

  List<AppClassModel> _classes = [];
  List<AppClassModel> get classes => _classes;
  List<AppClassModel> get registeredClasses => _classes;

  final Map<String, Map<String, dynamic>> _sessionMap = {};
  final Map<String, String> _registrationStatus = {};

  String _localRegisteredKey(int studentId) => 'local_registered_classes_$studentId';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("access_token") ??
        prefs.getString("token") ??
        prefs.getString("jwt") ??
        prefs.getString("accessToken");
  }

  int _getStudentId(String token) {
    try {
      final payload = token.split('.')[1];
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      );

      return int.tryParse(
        decoded["studentId"]?.toString() ??
            decoded["userId"]?.toString() ??
            decoded["id"]?.toString() ??
            decoded["sub"]?.toString() ??
            "",
      ) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  String _text(dynamic value) => value?.toString().trim() ?? "";

  List _safeList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data["content"] is List) return data["content"];
      if (data["data"] is List) return data["data"];
      if (data["result"] is List) return data["result"];
      if (data["items"] is List) return data["items"];
      if (data["records"] is List) return data["records"];

      if (data["data"] is Map && data["data"]["content"] is List) {
        return data["data"]["content"];
      }

      if (data["result"] is Map && data["result"]["content"] is List) {
        return data["result"]["content"];
      }

      if (data["data"] is Map && data["data"]["items"] is List) {
        return data["data"]["items"];
      }
    }

    return [];
  }

  String _getClassIdFromRegistration(Map<String, dynamic> m) {
    final nested = m["classroom"] ??
        m["classRoom"] ??
        m["class"] ??
        m["classes"] ??
        m["appClass"] ??
        m["clazz"];

    if (nested is Map) {
      final id = _text(
        nested["id"] ??
            nested["classId"] ??
            nested["classroomId"] ??
            nested["classRoomId"],
      );

      if (id.isNotEmpty && id != "0" && id.toLowerCase() != "null") {
        return id;
      }
    }

    return _text(
      m["classId"] ??
          m["classroomId"] ??
          m["classRoomId"] ??
          m["class_id"] ??
          m["idClass"] ??
          m["classIdId"],
    );
  }

  Map<String, dynamic>? _getClassMapFromRegistration(Map<String, dynamic> m) {
    final nested = m["classroom"] ??
        m["classRoom"] ??
        m["class"] ??
        m["classes"] ??
        m["appClass"] ??
        m["clazz"];

    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }

    return null;
  }

  String _getStudentIdFromRegistration(Map<String, dynamic> m) {
    final nested = m["student"] ?? m["user"] ?? m["account"];

    if (nested is Map) {
      final id = _text(
        nested["id"] ??
            nested["studentId"] ??
            nested["userId"],
      );

      if (id.isNotEmpty && id != "0") return id;
    }

    return _text(
      m["studentId"] ??
          m["userId"] ??
          m["accountId"] ??
          m["student_id"],
    );
  }

  String _getClassIdFromClassroom(Map<String, dynamic> m) {
    return _text(
      m["id"] ??
          m["classId"] ??
          m["classroomId"] ??
          m["classRoomId"],
    );
  }

  String _getClassIdFromSession(Map<String, dynamic> m) {
    final nested = m["classroom"] ?? m["classRoom"] ?? m["class"];

    if (nested is Map) {
      final id = _text(
        nested["id"] ??
            nested["classId"] ??
            nested["classroomId"] ??
            nested["classRoomId"],
      );

      if (id.isNotEmpty && id != "0") return id;
    }

    return _text(m["classId"] ?? m["classroomId"] ?? m["classRoomId"]);
  }

  String _getStatusFromRegistration(Map<String, dynamic> m) {
    final status = _text(
      m["status"] ??
          m["registrationStatus"] ??
          m["approveStatus"] ??
          m["state"] ??
          m["approvalStatus"],
    ).toUpperCase();

    return status.isEmpty ? "PENDING" : status;
  }

  bool _isApprovedStatus(String? status) {
    final s = status?.trim().toUpperCase() ?? "PENDING";

    return s == "APPROVED" ||
        s == "ACCEPTED" ||
        s == "APPROVE" ||
        s == "APPROVED_BY_ADMIN" ||
        s == "ACTIVE" ||
        s == "JOINED" ||
        s == "SUCCESS";
  }

  bool _isValidRegistrationStatus(String? status) {
    final s = status?.trim().toUpperCase() ?? "PENDING";

    return s == "PENDING" ||
        s == "APPROVED" ||
        s == "ACCEPTED" ||
        s == "APPROVE" ||
        s == "APPROVED_BY_ADMIN" ||
        s == "ACTIVE" ||
        s == "JOINED" ||
        s == "SUCCESS";
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    return DateTime.tryParse(raw)?.toLocal();
  }

  bool _isOpenStatus(dynamic status) {
    final s = status?.toString().trim().toUpperCase() ?? "";
    return s == "OPEN" || s == "ACTIVE" || s == "ONGOING" || s == "1";
  }

  bool _isSessionStillOpen(Map<String, dynamic> session) {
    if (!_isOpenStatus(session["status"])) return false;

    final end = _parseDateTime(
      session["endTime"] ??
          session["endDateTime"] ??
          session["attendanceEndTime"] ??
          session["closedAt"],
    );

    if (end == null) return true;

    return DateTime.now().isBefore(end);
  }

  AppClassModel _mapClassModel({
    required String classId,
    required Map<String, dynamic> m,
  }) {
    final title = _text(m["title"] ?? m["className"] ?? m["name"]);

    final teacher = _text(
      m["teacherName"] ??
          m["teacher"]?["fullName"] ??
          m["teacher"]?["name"],
    );

    final roomIdText = _text(m["roomId"] ?? m["locationId"]);
    double? radius;

    try {
      if (m["radius"] != null) {
        radius = (m["radius"] as num).toDouble();
      }
    } catch (_) {
      radius = null;
    }

    return AppClassModel(
      id: classId,
      className: title.isNotEmpty ? title : "Lớp học #$classId",
      teacherName: teacher.isNotEmpty ? teacher : "Chưa có giảng viên",
      description: _text(m["description"]).isNotEmpty
          ? _text(m["description"])
          : "Không có mô tả",
      teacherId: _text(m["teacherId"] ?? m["teacher"]?["id"]),
      startTime: _text(m["startDate"] ?? m["startTime"]).isNotEmpty
          ? _text(m["startDate"] ?? m["startTime"])
          : "-",
      endTime: _text(m["endDate"] ?? m["endTime"]).isNotEmpty
          ? _text(m["endDate"] ?? m["endTime"])
          : "-",
      roomId: roomIdText.isNotEmpty ? roomIdText : null,
      radius: radius,
      isAttendanceOpen: false,
    );
  }

  AppClassModel _fallbackClassModel(String classId) {
    return AppClassModel(
      id: classId,
      teacherId: "",
      teacherName: "Chưa có giảng viên",
      className: "Lớp học #$classId",
      description: "Không có mô tả",
      startTime: "-",
      endTime: "-",
      isAttendanceOpen: false,
    );
  }

  void _sortOpenClassToTop() {
    _classes.sort((a, b) {
      if (a.isAttendanceOpen && !b.isAttendanceOpen) return -1;
      if (!a.isAttendanceOpen && b.isAttendanceOpen) return 1;
      return 0;
    });
  }

  Future<Set<String>> _loadLocalRegisteredIds(int studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localRegisteredKey(studentId));

    if (raw == null || raw.isEmpty) return {};

    try {
      final data = jsonDecode(raw);
      if (data is List) {
        return data.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
      }
    } catch (_) {}

    return {};
  }

  Future<void> _saveLocalRegisteredIds(
      int studentId,
      Set<String> ids,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localRegisteredKey(studentId), jsonEncode(ids.toList()));
  }

  Future<List<Map<String, dynamic>>> _getAllRegistrations({
    required Map<String, String> headers,
    required int studentId,
  }) async {
    final result = <Map<String, dynamic>>[];

    final urls = [
      "$_baseUrl/class-registrations/$studentId/classes?page=0&size=100",
      "$_baseUrl/class-registrations/student/$studentId?page=0&size=100",
      "$_baseUrl/class-registrations?studentId=$studentId&page=0&size=100",
      "$_baseUrl/class-registrations?page=0&size=500",
    ];

    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url), headers: headers);

        debugPrint("REGISTERED API URL: $url");
        debugPrint("REGISTERED STATUS: ${res.statusCode}");
        debugPrint("REGISTERED BODY: ${utf8.decode(res.bodyBytes)}");

        if (res.statusCode != 200) continue;

        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        final list = _safeList(decoded);

        for (final raw in list) {
          if (raw is! Map) continue;

          final m = Map<String, dynamic>.from(raw);

          final sid = _getStudentIdFromRegistration(m);

          if (sid.isNotEmpty && sid != "0" && sid != studentId.toString()) {
            continue;
          }

          result.add(m);
        }
      } catch (e) {
        debugPrint("LOAD REGISTERED API ERROR: $url -> $e");
      }
    }

    return result;
  }

  Future<void> fetchRegisteredClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        _classes = [];
        return;
      }

      final studentId = _getStudentId(token);

      if (studentId == 0) {
        _classes = [];
        return;
      }

      final headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

      final registeredIds = <String>{};
      final classFromRegistration = <String, Map<String, dynamic>>{};

      _registrationStatus.clear();

      final localIds = await _loadLocalRegisteredIds(studentId);
      registeredIds.addAll(localIds);

      for (final id in localIds) {
        _registrationStatus[id] = "PENDING";
      }

      final registrations = await _getAllRegistrations(
        headers: headers,
        studentId: studentId,
      );

      for (final m in registrations) {
        final classId = _getClassIdFromRegistration(m);

        if (classId.isEmpty || classId == "0" || classId.toLowerCase() == "null") {
          debugPrint("SKIP REGISTRATION - CLASS ID EMPTY: $m");
          continue;
        }

        final status = _getStatusFromRegistration(m);

        if (!_isValidRegistrationStatus(status)) {
          continue;
        }

        registeredIds.add(classId);
        _registrationStatus[classId] = status;

        final nestedClass = _getClassMapFromRegistration(m);
        if (nestedClass != null) {
          classFromRegistration[classId] = nestedClass;
        }
      }

      await _saveLocalRegisteredIds(studentId, registeredIds);

      debugPrint("FINAL REGISTERED CLASS IDS: $registeredIds");

      final classroomMap = <String, Map<String, dynamic>>{};

      final classRes = await http.get(
        Uri.parse("$_baseUrl/classrooms?page=0&size=500"),
        headers: headers,
      );

      debugPrint("CLASSROOM STATUS: ${classRes.statusCode}");
      debugPrint("CLASSROOM BODY: ${utf8.decode(classRes.bodyBytes)}");

      if (classRes.statusCode == 200) {
        final classData = jsonDecode(utf8.decode(classRes.bodyBytes));
        final allClasses = _safeList(classData);

        for (final raw in allClasses) {
          if (raw is! Map) continue;

          final m = Map<String, dynamic>.from(raw);
          final classId = _getClassIdFromClassroom(m);

          if (classId.isEmpty || classId == "0") continue;

          classroomMap[classId] = m;
        }
      }

      _classes = [];

      for (final classId in registeredIds) {
        final classMap = classroomMap[classId] ?? classFromRegistration[classId];

        if (classMap == null) {
          _classes.add(_fallbackClassModel(classId));
          continue;
        }

        _classes.add(
          _mapClassModel(
            classId: classId,
            m: classMap,
          ),
        );
      }

      _sessionMap.clear();

      final sessionRes = await http.get(
        Uri.parse("$_baseUrl/sessions"),
        headers: headers,
      );

      debugPrint("SESSION STATUS: ${sessionRes.statusCode}");
      debugPrint("SESSION BODY: ${utf8.decode(sessionRes.bodyBytes)}");

      if (sessionRes.statusCode == 200) {
        final sessionData = jsonDecode(utf8.decode(sessionRes.bodyBytes));
        final sessions = _safeList(sessionData);

        for (final raw in sessions) {
          if (raw is! Map) continue;

          final sm = Map<String, dynamic>.from(raw);

          if (!_isSessionStillOpen(sm)) continue;

          final classId = _getClassIdFromSession(sm);

          if (classId.isNotEmpty && classId != "0") {
            _sessionMap[classId] = sm;
          }
        }
      }

      for (int i = 0; i < _classes.length; i++) {
        final c = _classes[i];
        final status = _registrationStatus[c.id] ?? "PENDING";
        final hasOpenSession = _sessionMap.containsKey(c.id);

        if (_isApprovedStatus(status) && hasOpenSession) {
          final s = _sessionMap[c.id]!;

          _classes[i] = c.copyWith(
            isAttendanceOpen: true,
            attendanceStartTime:
            (s["startTime"] ?? s["startDateTime"] ?? s["attendanceStartTime"])
                ?.toString(),
            attendanceEndTime:
            (s["endTime"] ?? s["endDateTime"] ?? s["attendanceEndTime"])
                ?.toString(),
          );
        } else {
          _classes[i] = c.copyWith(
            isAttendanceOpen: false,
            attendanceStartTime: null,
            attendanceEndTime: null,
          );
        }
      }

      updateCountdownAndCloseExpiredSessions(shouldNotify: false);
      _sortOpenClassToTop();
    } catch (e) {
      debugPrint("FETCH REGISTERED ERROR -> $e");
      _classes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateCountdownAndCloseExpiredSessions({bool shouldNotify = true}) {
    bool changed = false;

    for (int i = 0; i < _classes.length; i++) {
      final c = _classes[i];

      if (!c.isAttendanceOpen) continue;

      final end = c.attendanceEndDateTime;

      if (end != null && !DateTime.now().isBefore(end)) {
        _sessionMap.remove(c.id);

        _classes[i] = c.copyWith(
          isAttendanceOpen: false,
          attendanceStartTime: null,
          attendanceEndTime: null,
        );

        changed = true;
      }
    }

    if (shouldNotify || changed) {
      notifyListeners();
    }
  }

  String getRegistrationStatus(String classId) {
    return _registrationStatus[classId] ?? "PENDING";
  }

  bool isRegistrationApproved(String classId) {
    return _isApprovedStatus(_registrationStatus[classId]);
  }

  String getRegistrationStatusText(String classId) {
    final status = getRegistrationStatus(classId).toUpperCase();

    if (_isApprovedStatus(status)) {
      return "Đã được chấp nhận vào lớp";
    }

    if (status == "REJECTED" || status == "DECLINED") {
      return "Đăng ký lớp đã bị từ chối";
    }

    return "Đang chờ admin duyệt";
  }

  bool isClassActive(String classId) {
    return isClassAttendanceAvailable(classId);
  }

  bool isClassAttendanceAvailable(String classId) {
    final index = _classes.indexWhere((e) => e.id == classId);
    if (index == -1) return false;

    final c = _classes[index];

    if (!c.isAttendanceOpen) return false;
    if (!_sessionMap.containsKey(classId)) return false;

    final end = c.attendanceEndDateTime;
    if (end == null) return true;

    return DateTime.now().isBefore(end);
  }

  dynamic getActiveSessionId(String classId) {
    if (!isClassAttendanceAvailable(classId)) return null;

    return _sessionMap[classId]?["sessionId"] ??
        _sessionMap[classId]?["id"] ??
        _sessionMap[classId]?["attendanceSessionId"];
  }

  int? getSessionLocationId(String classId) {
    if (!isClassAttendanceAvailable(classId)) return null;

    final value = _sessionMap[classId]?["locationId"] ??
        _sessionMap[classId]?["location"]?["id"];

    if (value == null) return null;
    if (value is int) return value;

    return int.tryParse(value.toString());
  }

  String getRemainingTime(String classId) {
    final index = _classes.indexWhere((e) => e.id == classId);

    if (index == -1) return "";

    final c = _classes[index];
    final end = c.attendanceEndDateTime;

    if (end == null) return "";

    final diff = end.difference(DateTime.now());

    if (diff.inSeconds <= 0) return "00:00";

    final minutes = diff.inMinutes;
    final seconds = diff.inSeconds % 60;

    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  String getRemainingText(AppClassModel c) {
    if (!isClassAttendanceAvailable(c.id)) {
      return "Đã đóng";
    }

    final t = getRemainingTime(c.id);
    return t.isEmpty ? "Đang mở" : "Còn lại $t";
  }
}