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

  int _totalSessions = 0;
  int get totalSessions => _totalSessions;

  Future<void> fetchTotalSessions(String classId) async {
    try {
      final token = await _getValidToken();
      if (token == null || token.isEmpty) {
        throw Exception("Không tìm thấy token đăng nhập");
      }

      final headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

      final url = "$_baseUrl/sessions/class/$classId/count";
      final res = await http.get(Uri.parse(url), headers: headers);

      if (res.statusCode == 200) {
        final bodyText = utf8.decode(res.bodyBytes);
        // final data = jsonDecode(bodyText);
        // final count = (data is int) ? data : (data['count'] ?? 0);
        debugPrint("TOTAL SESSIONS BODY: $bodyText");
        final data = jsonDecode(bodyText);
        if (data is int) {
          _totalSessions = data;
        } else if (data is String) {
          _totalSessions = int.tryParse(data) ?? 0;
        } else if (data is Map<String, dynamic>) {
          _totalSessions = data['count'] ?? 0;
        }

        // _totalSessions = count;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("STATS TOTAL SESSIONS ERROR: $e");
    }
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      String realToken = token.trim();
      if (realToken.startsWith('Bearer ')) {
        realToken = realToken.replaceFirst('Bearer ', '').trim();
      }
      final payload = realToken.split('.')[1];
      return jsonDecode(
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(payload),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  bool _isTokenExpired(String token) {
    final jwt = _decodeJwt(token);
    final exp = jwt['exp'];
    if (exp == null) return false;
    final expInt = int.tryParse(exp.toString());
    if (expInt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= expInt;
  }

  bool _isJwtToken(String token) {
    final cleanToken = token.replaceFirst('Bearer ', '').trim();
    return cleanToken.split('.').length == 3;
  }


  Future<String?> _getValidToken() async {
    final prefs = await SharedPreferences.getInstance();

    final tokenKeys = [
      'access_token',
      'accessToken',
      'token',
      'jwt',
      'jwt_token',
      'auth_token',
      'access',
    ];

    for (final key in tokenKeys) {
      final value = prefs.getString(key);
      if (value == null || value.trim().isEmpty) continue;

      final token = value.trim();
      if (!_isJwtToken(token)) continue;
      if (_isTokenExpired(token)) continue;

      return token.replaceFirst('Bearer ', '').trim();
    }

    return null;
  }


  int get totalStudents => _statsList.length;

  String get avgAttendance {
    if (_statsList.isEmpty) return "0%";

    final total = _statsList.fold<double>(
      0,
          (sum, item) => sum + item.percentOfClass(),
    );

    return "${(total / _statsList.length).toStringAsFixed(0)}%";
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString("access_token") ??
        prefs.getString("token") ??
        prefs.getString("jwt") ??
        prefs.getString("accessToken");
  }

  List<dynamic> _safeList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data["content"] is List) return data["content"];
      if (data["data"] is List) return data["data"];
      if (data["result"] is List) return data["result"];
      if (data["items"] is List) return data["items"];
      if (data["records"] is List) return data["records"];
      if (data["attendanceRecords"] is List) return data["attendanceRecords"];

      if (data["data"] is Map) {
        final inner = data["data"];
        if (inner["content"] is List) return inner["content"];
        if (inner["records"] is List) return inner["records"];
        if (inner["items"] is List) return inner["items"];
        if (inner["attendanceRecords"] is List) {
          return inner["attendanceRecords"];
        }
      }

      if (data["result"] is Map) {
        final inner = data["result"];
        if (inner["content"] is List) return inner["content"];
        if (inner["records"] is List) return inner["records"];
        if (inner["items"] is List) return inner["items"];
        if (inner["attendanceRecords"] is List) {
          return inner["attendanceRecords"];
        }
      }
    }

    return [];
  }

  String _text(dynamic value, [String defaultValue = ""]) {
    if (value == null) return defaultValue;
    final text = value.toString().trim();
    return text.isEmpty ? defaultValue : text;
  }

  bool _isPresent(String status) {
    final s = status.trim().toUpperCase();

    return s == "PRESENT" ||
        s == "CHECKED_IN" ||
        s == "ATTENDED" ||
        s == "SUCCESS" ||
        s == "VALID" ||
        s == "DONE" ||
        s == "1" ||
        s == "TRUE";
  }

  String _getStatus(Map<String, dynamic> item) {
    return _text(
      item["recordStatus"] ??
          item["attendanceStatus"] ??
          item["status"] ??
          item["state"] ??
          item["result"],
      "UNKNOWN",
    ).toUpperCase();
  }

  String _getStudentId(Map<String, dynamic> item) {
    final nested = item["student"] ??
        item["user"] ??
        item["studentDto"] ??
        item["userDto"] ??
        item["account"];

    if (nested is Map) {
      final id = _text(
        nested["id"] ??
            nested["studentId"] ??
            nested["userId"] ??
            nested["accountId"],
      );

      if (id.isNotEmpty && id != "0") return id;
    }

    return _text(
      item["studentId"] ??
          item["userId"] ??
          item["accountId"] ??
          item["student_id"] ??
          item["id"],
      "0",
    );
  }

  String _getStudentName(Map<String, dynamic> item) {
    final nested = item["student"] ??
        item["user"] ??
        item["studentDto"] ??
        item["userDto"] ??
        item["account"];

    if (nested is Map) {
      final name = _text(
        nested["fullName"] ??
            nested["name"] ??
            nested["username"] ??
            nested["email"],
      );

      if (name.isNotEmpty) return name;
    }

    return _text(
      item["studentName"] ??
          item["fullName"] ??
          item["userName"] ??
          item["username"] ??
          item["email"],
      "Sinh viên chưa rõ tên",
    );
  }

  String _getClassIdFromRegistration(Map<String, dynamic> item) {
    final nested = item["classroom"] ??
        item["classRoom"] ??
        item["class"] ??
        item["clazz"];

    if (nested is Map) {
      final id = _text(
        nested["id"] ??
            nested["classId"] ??
            nested["classroomId"] ??
            nested["classRoomId"],
      );

      if (id.isNotEmpty && id != "0") return id;
    }

    return _text(
      item["classId"] ??
          item["classroomId"] ??
          item["classRoomId"] ??
          item["class_id"],
    );
  }

  String _getRegistrationStatus(Map<String, dynamic> item) {
    return _text(
      item["status"] ??
          item["registrationStatus"] ??
          item["approveStatus"] ??
          item["state"] ??
          item["approvalStatus"],
      "PENDING",
    ).toUpperCase();
  }

  bool _isAcceptedRegistration(String status) {
    final s = status.toUpperCase();

    return s == "ACCEPTED" ||
        s == "APPROVED" ||
        s == "APPROVE" ||
        s == "APPROVED_BY_ADMIN" ||
        s == "ACTIVE" ||
        s == "JOINED";
  }

  Future<List<Map<String, dynamic>>> _fetchAcceptedStudents({
    required String classId,
    required Map<String, String> headers,
  }) async {
    final result = <Map<String, dynamic>>[];

    final urls = [
      "$_baseUrl/class-registrations/$classId/students/status?page=0&size=500&status=ACCEPTED",
      // "$_baseUrl/class-registrations/$classId/students/status?page=0&size=500&status=APPROVED",
      // "$_baseUrl/class-registrations/class/$classId?page=0&size=500",
      // "$_baseUrl/class-registrations?page=0&size=500",
    ];

    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url), headers: headers);

        debugPrint("STATS REG URL: $url");
        debugPrint("STATS REG STATUS: ${res.statusCode}");
        debugPrint("STATS REG BODY: ${utf8.decode(res.bodyBytes)}");

        if (res.statusCode != 200) continue;

        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        final list = _safeList(decoded);

        for (final raw in list) {
          if (raw is! Map) continue;

          final item = Map<String, dynamic>.from(raw);

          final regClassId = _getClassIdFromRegistration(item);
          if (regClassId.isNotEmpty && regClassId != classId) continue;

          final status = _getRegistrationStatus(item);
          if (!_isAcceptedRegistration(status)) continue;

          final studentId = _getStudentId(item);
          if (studentId == "0") continue;

          result.add(item);
        }
      } catch (e) {
        debugPrint("STATS REG ERROR: $e");
      }
    }

    final unique = <String, Map<String, dynamic>>{};

    for (final item in result) {
      final id = _getStudentId(item);
      unique[id] = item;
    }

    return unique.values.toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceRecords({
    required String classId,
    required Map<String, String> headers,
  }) async {
    final urls = [
      // "$_baseUrl/attendance/class/$classId",
      // "$_baseUrl/attendance/classes/$classId",
      "$_baseUrl/attendance/class/$classId/student-stats",
      // "$_baseUrl/attendance?classId=$classId&page=0&size=500",
    ];

    final result = <Map<String, dynamic>>[];

    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url), headers: headers);

        debugPrint("STATS ATTENDANCE URL: $url");
        debugPrint("STATS ATTENDANCE STATUS: ${res.statusCode}");
        debugPrint("STATS ATTENDANCE BODY: ${utf8.decode(res.bodyBytes)}");

        if (res.statusCode != 200) continue;

        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        final list = _safeList(decoded);

        for (final raw in list) {
          if (raw is! Map) continue;
          result.add(Map<String, dynamic>.from(raw));
        }

        if (result.isNotEmpty) break;
      } catch (e) {
        debugPrint("STATS ATTENDANCE ERROR: $e");
      }
    }

    return result;
  }

  // Future<void> fetchClassStats(String classId) async {
  //   _isLoading = true;
  //   _statsList = [];
  //   notifyListeners();
  //
  //   try {
  //     final token = await _getValidToken();
  //     debugPrint("VALID TOKEN: $token");
  //     if (token == null || token.isEmpty) {
  //       debugPrint("STATS ERROR: Không tìm thấy token đăng nhập");
  //       return;
  //     }
  //
  //     final headers = {
  //       "Authorization": "Bearer $token",
  //       "Content-Type": "application/json",
  //       "Accept": "application/json",
  //     };
  //
  //     final acceptedStudents = await _fetchAcceptedStudents(
  //       classId: classId,
  //       headers: headers,
  //     );
  //
  //     final attendanceRecords = await _fetchAttendanceRecords(
  //       classId: classId,
  //       headers: headers,
  //     );
  //
  //     await fetchTotalSessions(classId);
  //
  //     final Map<String, StudentStatModel> mapStats = {};
  //
  //     for (final item in acceptedStudents) {
  //       final studentId = _getStudentId(item);
  //       final studentName = _getStudentName(item);
  //
  //       if (studentId == "0") continue;
  //
  //       mapStats.putIfAbsent(
  //         studentId,
  //             () => StudentStatModel(
  //           studentId: studentId,
  //           studentName: studentName,
  //         ),
  //       );
  //     }
  //
  //     for (final item in attendanceRecords) {
  //       final studentId = _getStudentId(item);
  //       final studentName = _getStudentName(item);
  //       final status = _getStatus(item);
  //
  //       if (studentId == "0") continue;
  //
  //       mapStats.putIfAbsent(
  //         studentId,
  //             () => StudentStatModel(
  //           studentId: studentId,
  //           studentName: studentName,
  //         ),
  //       );
  //
  //       if (_isPresent(status)) {
  //         mapStats[studentId]!.present++;
  //       } else {
  //         mapStats[studentId]!.absent++;
  //       }
  //     }
  //
  //     _statsList = mapStats.values.toList()
  //       ..sort((a, b) => a.studentName.compareTo(b.studentName));
  //
  //     debugPrint("THỐNG KÊ ĐƯỢC ${_statsList.length} SINH VIÊN");
  //   } catch (e) {
  //     debugPrint("STATS FLUTTER ERROR: $e");
  //     _statsList = [];
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

  Future<void> fetchClassStats(String classId) async {
    _isLoading = true;
    _statsList = [];
    notifyListeners();

    try {
      final token = await _getValidToken();
      if (token == null || token.isEmpty) {
        debugPrint("STATS ERROR: Không tìm thấy token đăng nhập");
        return;
      }

      final headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

      // Lấy danh sách sinh viên và điểm danh
      final acceptedStudents = await _fetchAcceptedStudents(
        classId: classId,
        headers: headers,
      );

      final attendanceRecords = await _fetchAttendanceRecords(
        classId: classId,
        headers: headers,
      );

      await fetchTotalSessions(classId);

      final Map<String, StudentStatModel> mapStats = {};

      for (final item in acceptedStudents) {
        final studentId = _getStudentId(item);
        final studentName = _getStudentName(item);
        if (studentId == "0") continue;

        mapStats.putIfAbsent(
          studentId,
              () => StudentStatModel(
            studentId: studentId,
            studentName: studentName,
            totalSessions: _totalSessions,
          ),
        );
      }

      for (final item in attendanceRecords) {
        final studentId = _getStudentId(item);
        final status = _getStatus(item);
        if (studentId == "0") continue;

        mapStats.putIfAbsent(
          studentId,
              () => StudentStatModel(
            studentId: studentId,
            studentName: _getStudentName(item),
            totalSessions: _totalSessions,
          ),
        );

        if (_isPresent(status)) {
          mapStats[studentId]!.present++;
        } else {
          mapStats[studentId]!.absent++;
        }
      }

      // _statsList = mapStats.values.toList()
      //   ..sort((a, b) => a.studentName.compareTo(b.studentName));

      _statsList = acceptedStudents.map((e) {
        final studentId = _getStudentId(e);
        final studentName = _getStudentName(e);

        // tìm record attendance tương ứng
        final record = attendanceRecords.firstWhere(
              (r) => r['studentId'].toString() == studentId,
          orElse: () => {},
        );

        return StudentStatModel(
          studentId: studentId,
          studentName: studentName,
          present: record.isNotEmpty ? (record['present'] ?? 0) : 0,
          absent: record.isNotEmpty ? (record['absent'] ?? 0) : 0,
          totalSessions: _totalSessions,
        );
      }).toList()
        ..sort((a, b) => a.studentName.compareTo(b.studentName));

      // _statsList = attendanceRecords.map((e) {
      //   return StudentStatModel(
      //     studentId: e['studentId'].toString(),
      //     studentName: e['studentName'],
      //     present: e['present'] ?? 0,
      //     absent: e['absent'] ?? 0,
      //     totalSessions: _totalSessions, // lấy từ fetchTotalSessions
      //   );
      // }).toList()
      //   ..sort((a, b) => a.studentName.compareTo(b.studentName));


      debugPrint("THỐNG KÊ ĐƯỢC ${_statsList.length} SINH VIÊN");
    } catch (e) {
      debugPrint("STATS FLUTTER ERROR: $e");
      _statsList = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  // Future<void> fetchClassStats(String classId) async {
  //   _isLoading = true;
  //   _statsList = [];
  //   notifyListeners();
  //
  //   try {
  //     final token = await _getValidToken();
  //     debugPrint("VALID TOKEN: $token");
  //     if (token == null || token.isEmpty) {
  //       debugPrint("STATS ERROR: Không tìm thấy token đăng nhập");
  //       return;
  //     }
  //
  //     final headers = {
  //       "Authorization": "Bearer $token",
  //       "Content-Type": "application/json",
  //       "Accept": "application/json",
  //     };
  //
  //     // Gọi API thống kê điểm danh từng sinh viên
  //     final url = "$_baseUrl/class-registrations/$classId/students/status?status=ACCEPTED";
  //     final res = await http.get(Uri.parse(url), headers: headers);
  //
  //     if (res.statusCode == 200) {
  //       // final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as List;
  //
  //       final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  //       final content = decoded['content'] as List;
  //
  //
  //       // Lấy tổng số buổi từ API sessions
  //       await fetchTotalSessions(classId);
  //
  //       // _statsList = decoded.map((e) {
  //       //   return StudentStatModel(
  //       //     studentId: e['studentId'].toString(),
  //       //     studentName: e['studentName'],
  //       //     present: e['present'] ?? 0,
  //       //     absent: e['absent'] ?? 0,
  //       //     totalSessions: _totalSessions,
  //       //   );
  //       // }).toList()
  //       //   ..sort((a, b) => a.studentName.compareTo(b.studentName));
  //
  //       _statsList = content.map((e) {
  //         return StudentStatModel(
  //           studentId: e['studentId'].toString(),
  //           studentName: e['studentName'],
  //           present: e['present'] ?? 0,
  //           absent: e['absent'] ?? 0,
  //           totalSessions: _totalSessions,
  //         );
  //       }).toList()
  //         ..sort((a, b) => a.studentName.compareTo(b.studentName));
  //
  //
  //       debugPrint("THỐNG KÊ ĐƯỢC ${_statsList.length} SINH VIÊN");
  //     } else {
  //       debugPrint("STATS ERROR: ${res.statusCode} - ${res.body}");
  //     }
  //   } catch (e) {
  //     debugPrint("STATS FLUTTER ERROR: $e");
  //     _statsList = [];
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }


  // Future<void> fetchClassStats(String classId) async {
  //   _isLoading = true;
  //   _statsList = [];
  //   notifyListeners();
  //
  //   try {
  //     final token = await _getValidToken();
  //     debugPrint("VALID TOKEN: $token");
  //     if (token == null || token.isEmpty) {
  //       debugPrint("STATS ERROR: Không tìm thấy token đăng nhập");
  //       return;
  //     }
  //
  //     final headers = {
  //       "Authorization": "Bearer $token",
  //       "Content-Type": "application/json",
  //       "Accept": "application/json",
  //     };
  //
  //     // Gọi API thống kê từng sinh viên
  //     final url = "$_baseUrl/class-registrations/$classId/students/status";
  //     final res = await http.get(Uri.parse(url), headers: headers);
  //
  //     if (res.statusCode == 200) {
  //       final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as List;
  //
  //       // Lấy tổng số buổi từ API sessions
  //       await fetchTotalSessions(classId);
  //
  //       _statsList = decoded.map((e) {
  //         return StudentStatModel(
  //           studentId: e['studentId'].toString(),
  //           studentName: e['studentName'],
  //           present: e['present'] ?? 0,
  //           absent: e['absent'] ?? 0,
  //           totalSessions: _totalSessions,
  //         );
  //       }).toList()
  //         ..sort((a, b) => a.studentName.compareTo(b.studentName));
  //
  //       debugPrint("THỐNG KÊ ĐƯỢC ${_statsList.length} SINH VIÊN");
  //     } else {
  //       debugPrint("STATS ERROR: ${res.statusCode} - ${res.body}");
  //     }
  //   } catch (e) {
  //     debugPrint("STATS FLUTTER ERROR: $e");
  //     _statsList = [];
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }


  Future<void> downloadExcel(String classId) async {
    try {
      final token = await _getValidToken();

      if (token == null || token.isEmpty) {
        debugPrint("EXCEL ERROR: Không tìm thấy token đăng nhập");
        return;
      }

      final url = Uri.parse("$_baseUrl/attendance/export/class/$classId");

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