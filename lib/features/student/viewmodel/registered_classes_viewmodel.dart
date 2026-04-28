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

  // Dòng này để đồng bộ với RegisteredClassesScreen
  List<AppClassModel> get registeredClasses => _classes;

  final Map<String, Map<String, dynamic>> _sessionMap = {};
  final Map<String, String> _registrationStatus = {};

  // ================= TOKEN =================

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
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(payload),
          ),
        ),
      );

      return int.parse(decoded["sub"].toString());
    } catch (_) {
      return 0;
    }
  }

  List _safeList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data["content"] is List) return data["content"];

      if (data["data"] is List) return data["data"];

      if (data["data"] is Map && data["data"]["content"] is List) {
        return data["data"]["content"];
      }
    }

    return [];
  }

  bool _isApprovedStatus(String? status) {
    final s = status?.trim().toUpperCase() ?? "PENDING";

    return s == "APPROVED" || s == "ACCEPTED" || s == "APPROVE";
  }

  void _sortOpenClassToTop() {
    _classes.sort((a, b) {
      if (a.isAttendanceOpen && !b.isAttendanceOpen) return -1;
      if (!a.isAttendanceOpen && b.isAttendanceOpen) return 1;
      return 0;
    });
  }

  // ================= FETCH =================

  Future<void> fetchRegisteredClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        throw Exception("No token");
      }

      final studentId = _getStudentId(token);

      if (studentId == 0) {
        throw Exception("Invalid student id from token");
      }

      final headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

      // ================= LẤY DANH SÁCH ĐĂNG KÝ CỦA SINH VIÊN =================

      final regRes = await http.get(
        Uri.parse(
          "$_baseUrl/class-registrations/$studentId/classes?page=0&size=100",
        ),
        headers: headers,
      );

      if (regRes.statusCode == 401 || regRes.statusCode == 403) {
        debugPrint("FETCH ERROR Unauthorized: ${regRes.statusCode}");
        return;
      }

      if (regRes.statusCode != 200) {
        throw Exception("Load registrations fail: ${regRes.statusCode}");
      }

      final regData = jsonDecode(
        utf8.decode(regRes.bodyBytes),
      );

      final regList = _safeList(regData);

      final Set<String> registeredIds = {};
      _registrationStatus.clear();

      for (var e in regList) {
        final m = Map<String, dynamic>.from(e);

        final id = m["classId"]?.toString() ??
            m["classroomId"]?.toString() ??
            m["id"]?.toString() ??
            "";

        if (id.isEmpty) continue;

        // Nếu backend không trả status thì mặc định là PENDING,
        // tuyệt đối không tự coi là đã duyệt.
        final status = m["status"]?.toString().toUpperCase() ?? "PENDING";

        registeredIds.add(id);
        _registrationStatus[id] = status;
      }

      // ================= LẤY THÔNG TIN LỚP =================

      final classRes = await http.get(
        Uri.parse("$_baseUrl/classrooms?page=0&size=100"),
        headers: headers,
      );

      if (classRes.statusCode == 401 || classRes.statusCode == 403) {
        debugPrint("FETCH ERROR Unauthorized classrooms: ${classRes.statusCode}");
        return;
      }

      if (classRes.statusCode != 200) {
        throw Exception("Load classrooms fail: ${classRes.statusCode}");
      }

      final classData = jsonDecode(
        utf8.decode(classRes.bodyBytes),
      );

      final allClasses = _safeList(classData);

      _classes = [];

      for (var e in allClasses) {
        final m = Map<String, dynamic>.from(e);

        final id = m["classId"]?.toString() ??
            m["id"]?.toString() ??
            "";

        if (id.isEmpty) continue;
        if (!registeredIds.contains(id)) continue;

        _classes.add(
          AppClassModel(
            id: id,
            className: m["title"]?.toString() ?? "Chưa có tên lớp",
            teacherName: m["teacherName"]?.toString() ?? "Chưa có giảng viên",
            description: m["description"]?.toString() ?? "Không có mô tả",
            teacherId: m["teacherId"]?.toString() ?? "",
            startTime: m["startDate"]?.toString() ?? "-",
            endTime: m["endDate"]?.toString() ?? "-",
            isAttendanceOpen: false,
          ),
        );
      }

      // ================= LẤY SESSION ĐIỂM DANH ĐANG MỞ =================

      _sessionMap.clear();

      final sessionRes = await http.get(
        Uri.parse("$_baseUrl/sessions"),
        headers: headers,
      );

      if (sessionRes.statusCode == 200) {
        final sessionData = jsonDecode(
          utf8.decode(sessionRes.bodyBytes),
        );

        final sessions = _safeList(sessionData);

        for (var s in sessions) {
          final sm = Map<String, dynamic>.from(s);

          final sessionStatus = sm["status"]?.toString().toUpperCase() ?? "";

          if (sessionStatus != "OPEN") continue;

          final classId = sm["classId"]?.toString() ??
              sm["classroomId"]?.toString() ??
              "";

          if (classId.isNotEmpty) {
            _sessionMap[classId] = sm;
          }
        }

        debugPrint("SessionMap: $_sessionMap");
      }

      // ================= CHỐT LOGIC ĐỒNG BỘ VỚI SCREEN =================
      // Chỉ khi:
      // 1. Admin đã duyệt: APPROVED / ACCEPTED / APPROVE
      // 2. Giáo viên đã mở session điểm danh
      // thì nút mới xanh và cho vào điểm danh.

      for (int i = 0; i < _classes.length; i++) {
        final c = _classes[i];
        final status = _registrationStatus[c.id] ?? "PENDING";
        final hasOpenSession = _sessionMap.containsKey(c.id);

        if (_isApprovedStatus(status) && hasOpenSession) {
          final s = _sessionMap[c.id]!;

          _classes[i] = c.copyWith(
            isAttendanceOpen: true,
            attendanceStartTime: s["startTime"]?.toString(),
            attendanceEndTime: s["endTime"]?.toString(),
          );
        } else {
          _classes[i] = c.copyWith(
            isAttendanceOpen: false,
            attendanceStartTime: null,
            attendanceEndTime: null,
          );
        }
      }

      _sortOpenClassToTop();
    } catch (e) {
      debugPrint("FETCH ERROR $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================= UI SUPPORT =================

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
    return _classes.any(
          (e) => e.id == classId && e.isAttendanceOpen,
    );
  }

  dynamic getActiveSessionId(String classId) {
    return _sessionMap[classId]?["sessionId"];
  }

  int? getSessionLocationId(String classId) {
    final value = _sessionMap[classId]?["locationId"];

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

    if (diff.inSeconds <= 0) return "";

    return "${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  String getRemainingText(AppClassModel c) {
    if (!c.isAttendanceOpen) {
      return "Chưa mở";
    }

    final t = getRemainingTime(c.id);

    return t.isEmpty ? "Đang mở" : "Còn lại $t";
  }

  @override
  void dispose() {
    super.dispose();
  }
}

