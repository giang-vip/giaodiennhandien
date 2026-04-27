import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/models/attendance_record_model.dart';

class AttendanceHistoryViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  List<AttendanceRecordModel> _history = [];
  List<AttendanceRecordModel> get history => _history;

  // ================= THỐNG KÊ =================

  int get totalSessions => _history.length;

  int get totalPresent =>
      _history.where((r) => _isPresentStatus(r.status)).length;

  int get totalAbsent =>
      _history.where((r) => !_isPresentStatus(r.status)).length;

  double get percentage {
    if (_history.isEmpty) return 0;
    return (totalPresent / _history.length) * 100;
  }

  String get percentageText => '${percentage.toStringAsFixed(0)}%';

  bool get hasData => _history.isNotEmpty;

  // ================= TOKEN =================

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

      if (!_isJwtToken(token)) {
        debugPrint('Bỏ qua token key=$key vì không phải JWT');
        continue;
      }

      if (_isTokenExpired(token)) {
        debugPrint('Bỏ qua token key=$key vì đã hết hạn');
        continue;
      }

      debugPrint('Dùng token key=$key');
      return token.replaceFirst('Bearer ', '').trim();
    }

    return null;
  }

  // ================= DATA HELPER =================

  List<dynamic> _safeList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data['content'] is List) return data['content'];
      if (data['data'] is List) return data['data'];

      if (data['data'] is Map && data['data']['content'] is List) {
        return data['data']['content'];
      }
    }

    return [];
  }

  bool _isPresentStatus(dynamic value) {
    final status = value?.toString().trim().toUpperCase() ?? '';

    return status == 'PRESENT' ||
        status == 'CHECKED_IN' ||
        status == 'ATTENDED' ||
        status == 'SUCCESS' ||
        status == '1' ||
        status == 'TRUE';
  }

  bool _isAbsentStatus(dynamic value) {
    final status = value?.toString().trim().toUpperCase() ?? '';

    return status == 'ABSENT' ||
        status == 'LATE' ||
        status == 'MISSED' ||
        status == 'FAILED' ||
        status == '0' ||
        status == 'FALSE';
  }

  String _normalizeStatus(dynamic value) {
    final raw = value?.toString().trim().toUpperCase() ?? 'UNKNOWN';

    if (_isPresentStatus(raw)) return 'PRESENT';
    if (_isAbsentStatus(raw)) return 'ABSENT';

    return raw.isEmpty ? 'UNKNOWN' : raw;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';

    final d = dateTime.day.toString().padLeft(2, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final y = dateTime.year.toString();

    return '$d/$m/$y';
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';

    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');

    return '$h:$m';
  }

  String _getSessionId(Map<String, dynamic> item, String fallback) {
    return item['attendanceSessionId']?.toString() ??
        item['sessionId']?.toString() ??
        item['recordId']?.toString() ??
        item['id']?.toString() ??
        fallback;
  }

  String? _getRecordClassId(Map<String, dynamic> item) {
    return item['classId']?.toString() ??
        item['classroomId']?.toString() ??
        item['classroom']?['id']?.toString() ??
        item['class']?['id']?.toString();
  }

  DateTime? _getRecordDateTime(Map<String, dynamic> item) {
    return _parseDateTime(
      item['checkinTime'] ??
          item['checkInTime'] ??
          item['createdAt'] ??
          item['createAt'] ??
          item['date'] ??
          item['time'],
    );
  }

  String _getRecordStatus(Map<String, dynamic> item) {
    return _normalizeStatus(
      item['recordStatus'] ??
          item['attendanceStatus'] ??
          item['status'] ??
          item['present'],
    );
  }

  // ================= FETCH HISTORY =================

  Future<void> fetchHistory(String classId) async {
    _isLoading = true;
    _errorMessage = '';
    _history = [];
    notifyListeners();

    try {
      final token = await _getValidToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Không tìm thấy token hợp lệ. Bạn hãy đăng xuất rồi đăng nhập lại.',
        );
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // USER thường chỉ được xem lịch sử của chính mình qua endpoint /me.
      // Không dùng /attendance/user/{id} vì endpoint đó chỉ dành cho ADMIN / LEADER.
      final url = Uri.parse('$_baseUrl/attendance/user/me');

      debugPrint('================= ATTENDANCE HISTORY API =================');
      debugPrint('URL: $url');
      debugPrint('TOKEN START: ${token.length > 20 ? token.substring(0, 20) : token}...');

      final response = await http.get(url, headers: headers);
      final bodyText = utf8.decode(response.bodyBytes);

      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('BODY: $bodyText');
      debugPrint('==========================================================');

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'Bạn không có quyền xem lịch sử hoặc phiên đăng nhập đã hết hạn.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception('Lấy lịch sử điểm danh thất bại: ${response.statusCode}');
      }

      final data = jsonDecode(bodyText);
      final content = _safeList(data);

      final Map<String, AttendanceRecordModel> uniqueRecords = {};

      for (final raw in content) {
        if (raw is! Map) continue;

        final item = Map<String, dynamic>.from(raw);
        final recordClassId = _getRecordClassId(item);

        // Nếu backend có trả classId/classroomId thì lọc theo lớp.
        // Nếu backend không trả classId thì vẫn hiển thị lịch sử của user.
        if (recordClassId != null && recordClassId.isNotEmpty && classId != '0') {
          if (recordClassId != classId) continue;
        }

        final dateTime = _getRecordDateTime(item);
        final date = _formatDate(dateTime);
        final time = _formatTime(dateTime);
        final status = _getRecordStatus(item);

        final fallbackKey = '${date}_${time}_$status';
        final sessionId = _getSessionId(item, fallbackKey);

        final oldRecord = uniqueRecords[sessionId];

        if (oldRecord == null) {
          uniqueRecords[sessionId] = AttendanceRecordModel(
            date: date,
            time: time,
            status: status,
            sessionId: sessionId,
          );
        } else {
          final oldPresent = _isPresentStatus(oldRecord.status);
          final newPresent = _isPresentStatus(status);

          if (!oldPresent && newPresent) {
            uniqueRecords[sessionId] = AttendanceRecordModel(
              date: date,
              time: time,
              status: status,
              sessionId: sessionId,
            );
          }
        }
      }

      _history = uniqueRecords.values.toList();

      _history.sort((a, b) {
        final ad = _parseDateTimeFromDisplay(a.date, a.time);
        final bd = _parseDateTimeFromDisplay(b.date, b.time);

        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;

        return bd.compareTo(ad);
      });
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      debugPrint('LỖI LẤY LỊCH SỬ ĐIỂM DANH: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DateTime? _parseDateTimeFromDisplay(String date, String time) {
    try {
      if (date == 'N/A') return null;

      final parts = date.split('/');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      int hour = 0;
      int minute = 0;

      if (time != 'N/A') {
        final timeParts = time.split(':');
        if (timeParts.length == 2) {
          hour = int.parse(timeParts[0]);
          minute = int.parse(timeParts[1]);
        }
      }

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }
}
