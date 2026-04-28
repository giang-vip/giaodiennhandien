import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/models/student_state_model.dart';

class StudentStatsViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<StudentStatModel> _statsList = [];
  List<StudentStatModel> get statsList => _statsList;

  int get totalStudents => _statsList.length;

  String get avgAttendance {
    if (_statsList.isEmpty) return "0%";

    double totalPerc = _statsList.fold(
      0,
          (sum, item) => sum + item.percent,
    );

    return "${(totalPerc / _statsList.length).toStringAsFixed(0)}%";
  }

  // ================= TOKEN =================

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString("access_token") ??
        prefs.getString("token") ??
        prefs.getString("jwt") ??
        prefs.getString("accessToken");
  }

  // ================= SAFE PARSE =================

  List<dynamic> _safeList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data["content"] is List) return data["content"];
      if (data["data"] is List) return data["data"];
      if (data["result"] is List) return data["result"];
      if (data["records"] is List) return data["records"];
      if (data["attendanceRecords"] is List) return data["attendanceRecords"];

      if (data["data"] is Map) {
        final inner = data["data"];
        if (inner["content"] is List) return inner["content"];
        if (inner["records"] is List) return inner["records"];
        if (inner["attendanceRecords"] is List) return inner["attendanceRecords"];
      }
    }

    return [];
  }

  String _readString(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    final text = value.toString().trim();
    return text.isEmpty ? defaultValue : text;
  }

  String _getStudentIdFromRecord(Map<String, dynamic> item) {
    final user = item["user"];
    final student = item["student"];
    final studentDto = item["studentDto"];
    final userDto = item["userDto"];

    if (user is Map && user["id"] != null) {
      return user["id"].toString();
    }

    if (student is Map && student["id"] != null) {
      return student["id"].toString();
    }

    if (studentDto is Map && studentDto["id"] != null) {
      return studentDto["id"].toString();
    }

    if (userDto is Map && userDto["id"] != null) {
      return userDto["id"].toString();
    }

    return item["userId"]?.toString() ??
        item["studentId"]?.toString() ??
        item["student_id"]?.toString() ??
        item["id"]?.toString() ??
        "0";
  }

  String _getStudentNameFromRecord(Map<String, dynamic> item) {
    final user = item["user"];
    final student = item["student"];
    final studentDto = item["studentDto"];
    final userDto = item["userDto"];

    if (user is Map) {
      final name = user["fullName"] ?? user["name"] ?? user["username"];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }

    if (student is Map) {
      final name = student["fullName"] ?? student["name"] ?? student["username"];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }

    if (studentDto is Map) {
      final name = studentDto["fullName"] ?? studentDto["name"] ?? studentDto["username"];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }

    if (userDto is Map) {
      final name = userDto["fullName"] ?? userDto["name"] ?? userDto["username"];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }

    return _readString(
      item["fullName"] ?? item["studentName"] ?? item["userName"] ?? item["username"],
      "Sinh viên ẩn danh",
    );
  }

  String _getStatusFromRecord(Map<String, dynamic> item) {
    return _readString(
      item["recordStatus"] ??
          item["attendanceStatus"] ??
          item["status"] ??
          item["state"] ??
          item["result"],
      "UNKNOWN",
    ).toUpperCase();
  }

  bool _isPresent(String status) {
    final s = status.trim().toUpperCase();

    return s == "PRESENT" ||
        s == "CHECKED_IN" ||
        s == "ATTENDED" ||
        s == "SUCCESS" ||
        s == "1" ||
        s == "TRUE";
  }

  // =========================================================================
  // 1. GỌI API LẤY DANH SÁCH ĐIỂM DANH VÀ THỐNG KÊ THEO LỚP
  // =========================================================================

  Future<void> fetchClassStats(String classId) async {
    _isLoading = true;
    _statsList = [];
    notifyListeners();

    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        debugPrint("STATS ERROR: Không tìm thấy token đăng nhập");
        return;
      }

      final headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

      // API thống kê theo lớp.
      // Nếu backend của bạn dùng endpoint khác thì chỉ cần đổi dòng này.
      final url = Uri.parse("$_baseUrl/attendance/class/$classId");

      debugPrint("\n================= BẮT ĐẦU GỌI API THỐNG KÊ LỚP =================");
      debugPrint("CLASS ID: $classId");
      debugPrint("GỌI LINK: $url");

      final response = await http.get(url, headers: headers);

      debugPrint("HTTP STATUS: ${response.statusCode}");
      debugPrint("DỮ LIỆU TỪ BACKEND TRẢ VỀ:");
      debugPrint(utf8.decode(response.bodyBytes));
      debugPrint("=================================================================\n");

      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint("STATS ERROR: Token hết hạn hoặc không có quyền xem thống kê");
        _statsList = [];
        return;
      }

      if (response.statusCode == 404) {
        debugPrint("STATS ERROR 404: API không tồn tại hoặc chưa có dữ liệu điểm danh cho lớp này");
        _statsList = [];
        return;
      }

      if (response.statusCode != 200) {
        debugPrint("STATS ERROR: Backend trả về mã ${response.statusCode}");
        _statsList = [];
        return;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = _safeList(data);

      final Map<String, StudentStatModel> mapStats = {};

      for (final rawItem in content) {
        if (rawItem is! Map) continue;

        final item = Map<String, dynamic>.from(rawItem);

        final uid = _getStudentIdFromRecord(item);
        final name = _getStudentNameFromRecord(item);
        final status = _getStatusFromRecord(item);

        if (uid == "0") continue;

        mapStats.putIfAbsent(
          uid,
              () => StudentStatModel(
            studentName: name,
            studentId: uid,
          ),
        );

        if (_isPresent(status)) {
          mapStats[uid]!.present++;
        } else {
          mapStats[uid]!.absent++;
        }
      }

      _statsList = mapStats.values.toList()
        ..sort((a, b) => a.studentName.compareTo(b.studentName));

      debugPrint("THỐNG KÊ ĐƯỢC ${_statsList.length} SINH VIÊN");
    } catch (e) {
      debugPrint("STATS FLUTTER ERROR: $e");
      _statsList = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // 2. HÀM TẢI FILE EXCEL
  // =========================================================================

  Future<void> downloadExcel(String classId) async {
    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        debugPrint("EXCEL ERROR: Không tìm thấy token đăng nhập");
        return;
      }

      final url = Uri.parse("$_baseUrl/attendance/export/class/$classId");

      debugPrint("\nĐANG GỌI LINK TẢI EXCEL: $url");

      // Lưu ý: launchUrl chỉ mở link trên trình duyệt.
      // Nếu backend bắt buộc Authorization Bearer token thì trình duyệt sẽ không gửi token.
      // Khi đó cần viết API export cho phép download bằng query token hoặc tải file bằng http.get rồi lưu file.
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint("Không thể mở trình duyệt để tải file Excel");
      }
    } catch (e) {
      debugPrint("Lỗi khi tải Excel: $e");
    }
  }
}
