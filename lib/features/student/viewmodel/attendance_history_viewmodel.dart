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

  // int get totalSessions => _history.length;
  int _totalSessions = 0;
  int get totalSessions => _totalSessions;

  Future<void> fetchTotalSessions(String classId) async {
    try {
      final token = await _getValidToken();
      if (token == null || token.isEmpty) {
        throw Exception('Không tìm thấy token hợp lệ.');
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final url = '$_baseUrl/sessions/class/$classId/count';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final bodyText = utf8.decode(response.bodyBytes);
        final count = int.tryParse(bodyText) ?? 0;
        _totalSessions = count;
        notifyListeners();
      } else {
        throw Exception('Không lấy được tổng số buổi điểm danh.');
      }
    } catch (e) {
      debugPrint('Lỗi lấy tổng số buổi: $e');
    }
  }

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

      if (!_isJwtToken(token)) continue;
      if (_isTokenExpired(token)) continue;

      return token.replaceFirst('Bearer ', '').trim();
    }

    return null;
  }

  // ================= SAFE PARSE =================

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

  Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  bool _sameId(dynamic a, dynamic b) {
    final x = _asString(a);
    final y = _asString(b);
    if (x == null || y == null) return false;
    return x == y;
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

  // ================= GET FIELD =================

  String? _getSessionIdFromRecord(Map<String, dynamic> item) {
    return _asString(item['attendanceSessionId']) ??
        _asString(item['sessionId']) ??
        _asString(item['attendance_session_id']) ??
        _asString(item['session_id']) ??
        _asString(item['session']?['id']) ??
        _asString(item['session']?['sessionId']) ??
        _asString(item['attendanceSession']?['id']) ??
        _asString(item['attendanceSession']?['sessionId']);
  }

  String? _getRecordClassId(Map<String, dynamic> item) {
    return _asString(item['classId']) ??
        _asString(item['classroomId']) ??
        _asString(item['classRoomId']) ??
        _asString(item['roomId']) ??
        _asString(item['class_id']) ??
        _asString(item['classroom_id']) ??
        _asString(item['classroom']?['id']) ??
        _asString(item['classroom']?['classId']) ??
        _asString(item['classRoom']?['id']) ??
        _asString(item['classRoom']?['classId']) ??
        _asString(item['class']?['id']) ??
        _asString(item['class']?['classId']) ??
        _asString(item['session']?['classId']) ??
        _asString(item['session']?['classroomId']) ??
        _asString(item['attendanceSession']?['classId']) ??
        _asString(item['attendanceSession']?['classroomId']);
  }

  String? _getSessionIdFromSession(Map<String, dynamic> session) {
    return _asString(session['attendanceSessionId']) ??
        _asString(session['sessionId']) ??
        _asString(session['id']) ??
        _asString(session['attendance_session_id']) ??
        _asString(session['session_id']);
  }

  String? _getClassIdFromSession(Map<String, dynamic> session) {
    return _asString(session['classId']) ??
        _asString(session['classroomId']) ??
        _asString(session['classRoomId']) ??
        _asString(session['class_id']) ??
        _asString(session['classroom_id']) ??
        _asString(session['classroom']?['id']) ??
        _asString(session['classroom']?['classId']) ??
        _asString(session['classRoom']?['id']) ??
        _asString(session['classRoom']?['classId']) ??
        _asString(session['class']?['id']) ??
        _asString(session['class']?['classId']);
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

  String _getRecordUniqueKey({
    required Map<String, dynamic> item,
    required String date,
    required String time,
    required String status,
  }) {
    final recordId = _asString(item['recordId']) ?? _asString(item['id']);
    final sessionId = _getSessionIdFromRecord(item);

    if (sessionId != null) return 'session_$sessionId';
    if (recordId != null) return 'record_$recordId';

    return '${date}_${time}_$status';
  }

  // ================= API HELPERS =================

  Future<List<dynamic>> _getListFromApi({
    required String url,
    required Map<String, String> headers,
  }) async {
    final response = await http.get(Uri.parse(url), headers: headers);

    debugPrint('GET $url -> ${response.statusCode}');

    if (response.statusCode != 200) return [];

    final bodyText = utf8.decode(response.bodyBytes);
    final data = jsonDecode(bodyText);
    return _safeList(data);
  }

  //khả năng là lấy all session *************************************************************************************************
  Future<Set<String>> _fetchSessionIdsOfClass({
    required String classId,
    required Map<String, String> headers,
  }) async {
    final Set<String> result = {};

    final sessionUrls = [
      '$_baseUrl/sessions?classId=$classId',
      '$_baseUrl/sessions?classroomId=$classId',
      '$_baseUrl/sessions/class/$classId',
      '$_baseUrl/sessions/classroom/$classId',
      '$_baseUrl/sessions',
    ];

    for (final url in sessionUrls) {
      final sessions = await _getListFromApi(url: url, headers: headers);

      for (final raw in sessions) {
        final session = _safeMap(raw);
        if (session == null) continue;

        final sClassId = _getClassIdFromSession(session);
        if (!_sameId(sClassId, classId)) continue;

        final sessionId = _getSessionIdFromSession(session);
        if (sessionId != null) result.add(sessionId);
      }

      if (result.isNotEmpty) break;
    }

    debugPrint('SESSION IDS OF CLASS $classId = $result');
    return result;
  }

  Future<List<dynamic>> _fetchAttendanceRecordsByBestEndpoint({
    required String classId,
    required Map<String, String> headers,
  }) async {
    final candidateUrls = [
      // Ưu tiên endpoint có filter classId nếu backend có hỗ trợ.
      '$_baseUrl/attendance/user/me?classId=$classId',
      '$_baseUrl/attendance/user/me?classroomId=$classId',
      '$_baseUrl/attendance/me/class/$classId',
      '$_baseUrl/attendance/class/$classId/me',
      '$_baseUrl/attendance/classroom/$classId/me',
      // Fallback cuối cùng: lấy toàn bộ rồi tự lọc thật chặt ở client.
      '$_baseUrl/attendance/user/me',
    ];

    for (final url in candidateUrls) {
      final response = await http.get(Uri.parse(url), headers: headers);
      final bodyText = utf8.decode(response.bodyBytes);

      debugPrint('================= ATTENDANCE API TRY =================');
      debugPrint('URL: $url');
      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('BODY: $bodyText');
      debugPrint('=====================================================');

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'Bạn không có quyền xem lịch sử hoặc phiên đăng nhập đã hết hạn.',
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(bodyText);
        return _safeList(data);
      }
    }

    throw Exception('Lấy lịch sử điểm danh thất bại.');
  }

  bool _recordBelongsToClass({
    required Map<String, dynamic> item,
    required String classId,
    required Set<String> sessionIdsOfClass,
  }) {
    final recordClassId = _getRecordClassId(item);

    // Ưu tiên lọc bằng classId trực tiếp trong record.
    if (recordClassId != null) {
      return _sameId(recordClassId, classId);
    }

    // Nếu record không có classId thì lọc bằng sessionId thuộc lớp đó.
    final recordSessionId = _getSessionIdFromRecord(item);
    if (recordSessionId != null && sessionIdsOfClass.isNotEmpty) {
      return sessionIdsOfClass.contains(recordSessionId);
    }

    // QUAN TRỌNG:
    // Không được return true ở đây.
    // Nếu không xác định được record thuộc lớp nào thì bỏ qua,
    // tránh lỗi lớp nào cũng thống kê giống nhau.
    return false;
  }

  // ================= FETCH HISTORY =================

  Future<void> fetchHistory(String classId) async {
    _isLoading = true;
    _errorMessage = '';
    _history = [];
    notifyListeners();

    try {
      final currentClassId = classId.trim();

      if (currentClassId.isEmpty || currentClassId == '0') {
        throw Exception('Không xác định được lớp cần xem thống kê.');
      }

      await fetchTotalSessions(currentClassId);

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

      final sessionIdsOfClass = await _fetchSessionIdsOfClass(
        classId: currentClassId,
        headers: headers,
      );

      final content = await _fetchAttendanceRecordsByBestEndpoint(
        classId: currentClassId,
        headers: headers,
      );

      final Map<String, AttendanceRecordModel> uniqueRecords = {};

      int skipped = 0;
      int accepted = 0;

      for (final raw in content) {
        final item = _safeMap(raw);
        if (item == null) continue;

        final belongs = _recordBelongsToClass(
          item: item,
          classId: currentClassId,
          sessionIdsOfClass: sessionIdsOfClass,
        );

        if (!belongs) {
          skipped++;
          continue;
        }

        accepted++;

        final dateTime = _getRecordDateTime(item);
        final date = _formatDate(dateTime);
        final time = _formatTime(dateTime);
        final status = _getRecordStatus(item);

        final uniqueKey = _getRecordUniqueKey(
          item: item,
          date: date,
          time: time,
          status: status,
        );

        final oldRecord = uniqueRecords[uniqueKey];

        if (oldRecord == null) {
          uniqueRecords[uniqueKey] = AttendanceRecordModel(
            date: date,
            time: time,
            status: status,
            sessionId: uniqueKey,
          );
        } else {
          final oldPresent = _isPresentStatus(oldRecord.status);
          final newPresent = _isPresentStatus(status);

          if (!oldPresent && newPresent) {
            uniqueRecords[uniqueKey] = AttendanceRecordModel(
              date: date,
              time: time,
              status: status,
              sessionId: uniqueKey,
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

      debugPrint('================= FILTER RESULT =================');
      debugPrint('CLASS ID: $currentClassId');
      debugPrint('ACCEPTED RECORDS: $accepted');
      debugPrint('SKIPPED RECORDS: $skipped');
      debugPrint('FINAL UNIQUE HISTORY: ${_totalSessions}');
      debugPrint('=================================================');
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
