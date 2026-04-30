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

    return DateTime.tryParse(text)?.toLocal();
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
        item['session']?['id']?.toString() ??
        item['attendanceSession']?['id']?.toString() ??
        item['recordId']?.toString() ??
        item['id']?.toString() ??
        fallback;
  }

  String? _getRecordClassId(Map<String, dynamic> item) {
    return item['classId']?.toString() ??
        item['classroomId']?.toString() ??
        item['classRoomId']?.toString() ??
        item['roomId']?.toString() ??
        item['classroom']?['id']?.toString() ??
        item['classroom']?['classId']?.toString() ??
        item['class']?['id']?.toString() ??
        item['class']?['classId']?.toString() ??
        item['session']?['classId']?.toString() ??
        item['session']?['classroomId']?.toString() ??
        item['attendanceSession']?['classId']?.toString() ??
        item['attendanceSession']?['classroomId']?.toString();
  }

  DateTime? _getRecordDateTime(Map<String, dynamic> item) {
    return _parseDateTime(
      item['checkinTime'] ??
          item['checkInTime'] ??
          item['checkedInAt'] ??
          item['attendanceTime'] ??
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

  String? _getSessionClassId(Map<String, dynamic> session) {
    return session['classId']?.toString() ??
        session['classroomId']?.toString() ??
        session['classRoomId']?.toString() ??
        session['classroom']?['id']?.toString() ??
        session['classroom']?['classId']?.toString() ??
        session['class']?['id']?.toString() ??
        session['class']?['classId']?.toString();
  }

  String? _getSessionKey(Map<String, dynamic> session) {
    return session['attendanceSessionId']?.toString() ??
        session['sessionId']?.toString() ??
        session['id']?.toString();
  }

  Future<Map<String, String>> _fetchSessionClassMap({
    required Map<String, String> headers,
  }) async {
    final Map<String, String> sessionClassMap = {};

    try {
      final url = Uri.parse('$_baseUrl/sessions');
      final response = await http.get(url, headers: headers);

      debugPrint('================= SESSION MAP API =================');
      debugPrint('URL: $url');
      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('===================================================');

      if (response.statusCode != 200) return sessionClassMap;

      final bodyText = utf8.decode(response.bodyBytes);
      final data = jsonDecode(bodyText);
      final sessions = _safeList(data);

      for (final raw in sessions) {
        if (raw is! Map) continue;

        final session = Map<String, dynamic>.from(raw);
        final sessionId = _getSessionKey(session);
        final sessionClassId = _getSessionClassId(session);

        if (sessionId == null || sessionId.isEmpty) continue;
        if (sessionClassId == null || sessionClassId.isEmpty) continue;

        sessionClassMap[sessionId] = sessionClassId;
      }
    } catch (e) {
      debugPrint('Không lấy được session map: $e');
    }

    return sessionClassMap;
  }

  bool _isRecordOfCurrentClass({
    required Map<String, dynamic> item,
    required String targetClassId,
    required Map<String, String> sessionClassMap,
    required String fallbackSessionId,
  }) {
    if (targetClassId == '0' || targetClassId.trim().isEmpty) return true;

    final recordClassId = _getRecordClassId(item);

    if (recordClassId != null && recordClassId.isNotEmpty) {
      return recordClassId == targetClassId;
    }

    final sessionId = _getSessionId(item, fallbackSessionId);
    final mappedClassId = sessionClassMap[sessionId];

    if (mappedClassId != null && mappedClassId.isNotEmpty) {
      return mappedClassId == targetClassId;
    }

    // FIX QUAN TRỌNG:
    // Nếu record không có classId và cũng không map được sessionId sang classId
    // thì KHÔNG được đưa vào mọi lớp nữa, vì sẽ làm tất cả lớp thống kê giống nhau.
    return false;
  }

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

      final sessionClassMap = await _fetchSessionClassMap(headers: headers);

      final url = Uri.parse('$_baseUrl/attendance/user/me');

      debugPrint('================= ATTENDANCE HISTORY API =================');
      debugPrint('URL: $url');
      debugPrint('CLASS ID FILTER: $classId');
      debugPrint('SESSION MAP SIZE: ${sessionClassMap.length}');
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
        final dateTime = _getRecordDateTime(item);
        final date = _formatDate(dateTime);
        final time = _formatTime(dateTime);
        final status = _getRecordStatus(item);

        final fallbackKey = '${date}_${time}_$status';
        final sessionId = _getSessionId(item, fallbackKey);

        final isCurrentClass = _isRecordOfCurrentClass(
          item: item,
          targetClassId: classId,
          sessionClassMap: sessionClassMap,
          fallbackSessionId: fallbackKey,
        );

        if (!isCurrentClass) continue;

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

      debugPrint('FILTERED HISTORY FOR CLASS $classId: ${_history.length} records');
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
