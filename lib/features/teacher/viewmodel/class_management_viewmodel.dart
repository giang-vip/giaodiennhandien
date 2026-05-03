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

  String _localSessionKey(String classId) => 'local_open_session_$classId';

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
    } catch (_) {
      return {};
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ??
        prefs.getString('token') ??
        prefs.getString('jwt') ??
        prefs.getString('accessToken');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy token. Vui lòng đăng nhập lại.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  List _safeList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data['data'] is Map && data['data']['content'] is List) {
        return data['data']['content'];
      }
      if (data['result'] is Map && data['result']['content'] is List) {
        return data['result']['content'];
      }
      if (data['content'] is List) return data['content'];
      if (data['data'] is List) return data['data'];
      if (data['result'] is List) return data['result'];
      if (data['items'] is List) return data['items'];
    }

    return [];
  }

  String _getClassId(Map<String, dynamic> item) {
    return item['id']?.toString() ??
        item['classId']?.toString() ??
        item['classroomId']?.toString() ??
        item['classRoomId']?.toString() ??
        '';
  }

  String _getTeacherId(Map<String, dynamic> item) {
    return item['teacherId']?.toString() ??
        item['teacher']?['id']?.toString() ??
        item['teacher']?['userId']?.toString() ??
        item['user']?['id']?.toString() ??
        item['createdBy']?.toString() ??
        '';
  }

  String _getSessionClassId(Map<String, dynamic> s) {
    return s['classroom']?['id']?.toString() ??
        s['classRoom']?['id']?.toString() ??
        s['class']?['id']?.toString() ??
        s['classroomId']?.toString() ??
        s['classId']?.toString() ??
        s['classRoomId']?.toString() ??
        '';
  }

  bool _isOpenStatus(dynamic status) {
    final s = status?.toString().trim().toUpperCase() ?? '';
    return s == 'OPEN' || s == 'ACTIVE' || s == 'ONGOING' || s == '1';
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  int? _parsePositiveInt(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final n = int.tryParse(text);
    if (n == null || n <= 0) return null;
    return n;
  }

  int _calculateAttendanceMinutes(dynamic start, dynamic end) {
    final s = _parseDateTime(start);
    final e = _parseDateTime(end);

    if (s == null || e == null) return 0;

    final m = e.difference(s).inMinutes;
    return m > 0 ? m : 0;
  }

  String? _getSavedLocationId({
    required SharedPreferences prefs,
    required String classId,
    required Map<String, dynamic> item,
  }) {
    final savedRoom = prefs.getString('class_${classId}_room');
    final savedLocation = prefs.getString('class_${classId}_location');
    final savedOther = prefs.getString('location_$classId');

    if (savedRoom != null && savedRoom.trim().isNotEmpty) {
      return savedRoom.trim();
    }
    if (savedLocation != null && savedLocation.trim().isNotEmpty) {
      return savedLocation.trim();
    }
    if (savedOther != null && savedOther.trim().isNotEmpty) {
      return savedOther.trim();
    }

    final locationIds = item['locationIds'];
    if (locationIds is List && locationIds.isNotEmpty) {
      return locationIds.first.toString();
    }

    final locations = item['locations'];
    if (locations is List && locations.isNotEmpty) {
      final first = locations.first;
      if (first is Map && first['id'] != null) return first['id'].toString();
      return first.toString();
    }

    final location = item['location'];
    if (location is Map && location['id'] != null) {
      return location['id'].toString();
    }

    return item['locationId']?.toString() ?? item['roomId']?.toString();
  }

  int? _getClassLocationId(AppClassModel c) {
    return _parsePositiveInt(c.roomId);
  }

  int? _getSessionLocationId(Map<String, dynamic>? s) {
    if (s == null) return null;

    final location = s['location'];
    dynamic nestedId;
    if (location is Map) nestedId = location['id'];

    return _parsePositiveInt(s['locationId'] ?? nestedId);
  }

  String _extractErrorMessage(http.Response res, String fallback) {
    try {
      final body = utf8.decode(res.bodyBytes);
      debugPrint('API ERROR STATUS -> ${res.statusCode}');
      debugPrint('API ERROR BODY -> $body');

      if (body.trim().isEmpty) return '$fallback (${res.statusCode})';

      final data = jsonDecode(body);
      if (data is Map) {
        return data['message']?.toString() ??
            data['error']?.toString() ??
            data['detail']?.toString() ??
            data['title']?.toString() ??
            '$fallback (${res.statusCode})';
      }
    } catch (_) {}

    return '$fallback (${res.statusCode})';
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

  void _sortClasses() {
    _realClasses.sort((a, b) {
      if (a.isAttendanceOpen && !b.isAttendanceOpen) return -1;
      if (!a.isAttendanceOpen && b.isAttendanceOpen) return 1;
      return 0;
    });
  }

  Future<void> _saveLocalOpenSession(
      String classId,
      Map<String, dynamic> data,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localSessionKey(classId), jsonEncode(data));
  }

  Future<void> _removeLocalOpenSession(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localSessionKey(classId));
  }

  Future<void> _clearAllLocalOpenSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
          (key) => key.startsWith('local_open_session_'),
    );

    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<Map<String, dynamic>?> _loadLocalOpenSession(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localSessionKey(classId));

    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      await prefs.remove(_localSessionKey(classId));
    }

    return null;
  }

  Future<void> fetchClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final headers = await _getHeaders();
      final token = await _getToken();
      final jwt = token == null ? {} : _decodeJwt(token);
      final myTeacherId = jwt['sub']?.toString() ?? '';

      _cancelAllTimers();
      _activeSessionData.clear();

      final classRes = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=100'),
        headers: headers,
      );

      debugPrint('CLASSROOM STATUS -> ${classRes.statusCode}');
      debugPrint('CLASSROOM BODY -> ${utf8.decode(classRes.bodyBytes)}');

      if (classRes.statusCode != 200) {
        _realClasses = [];
        return;
      }

      final classData = jsonDecode(utf8.decode(classRes.bodyBytes));
      final classList = _safeList(classData);
      final prefs = await SharedPreferences.getInstance();

      _realClasses = classList.map((raw) {
        final item = Map<String, dynamic>.from(raw);
        final classId = _getClassId(item);
        final teacherId = _getTeacherId(item);

        return AppClassModel(
          id: classId,
          teacherId: teacherId,
          className: item['title']?.toString() ??
              item['className']?.toString() ??
              item['name']?.toString() ??
              'Chưa có tên lớp',
          description: item['description']?.toString() ?? '',
          teacherName: item['teacherName']?.toString() ??
              item['teacher']?['fullName']?.toString() ??
              item['teacher']?['name']?.toString() ??
              '',
          startTime: item['startDate']?.toString() ??
              item['startTime']?.toString() ??
              '',
          endTime: item['endDate']?.toString() ??
              item['endTime']?.toString() ??
              '',
          isAttendanceOpen: false,
          attendanceDuration: 0,
          roomId: _getSavedLocationId(
            prefs: prefs,
            classId: classId,
            item: item,
          ),
          radius: prefs.getDouble('class_${classId}_radius'),
        );
      }).where((c) {
        if (c.id.isEmpty || c.id == '0') return false;

        if (myTeacherId.isEmpty) return true;
        if (c.teacherId.isEmpty) return true;

        return c.teacherId == myTeacherId;
      }).toList();

      final sessionRes = await http.get(
        Uri.parse('$_baseUrl/sessions'),
        headers: headers,
      );

      debugPrint('SESSION LIST STATUS -> ${sessionRes.statusCode}');
      debugPrint('SESSION LIST BODY -> ${utf8.decode(sessionRes.bodyBytes)}');

      if (sessionRes.statusCode == 200) {
        final sessionData = jsonDecode(utf8.decode(sessionRes.bodyBytes));
        final sessionList = _safeList(sessionData);

        final openedIdsFromDb = <String>{};

        for (final raw in sessionList) {
          final s = Map<String, dynamic>.from(raw);
          if (!_isOpenStatus(s['status'])) continue;

          final classId = _getSessionClassId(s);
          if (classId.isEmpty) continue;

          final end = _parseDateTime(s['endTime'] ?? s['endDateTime']);

          if (end != null && !DateTime.now().isBefore(end)) {
            await _closeSessionByRawData(classId, s, silent: true);
            continue;
          }

          openedIdsFromDb.add(classId);

          final sessionMap = {
            'sessionId': s['sessionId'] ?? s['id'] ?? s['attendanceSessionId'],
            'locationId': s['locationId'] ??
                (s['location'] is Map ? s['location']['id'] : null),
            'title': s['title'],
            'startTime': s['startTime'] ?? s['startDateTime'],
            'endTime': s['endTime'] ?? s['endDateTime'],
            'raw': s,
          };

          _activeSessionData[classId] = sessionMap;
          await _saveLocalOpenSession(classId, sessionMap);
        }

        final prefs = await SharedPreferences.getInstance();
        final localKeys = prefs.getKeys().where(
              (key) => key.startsWith('local_open_session_'),
        );

        for (final key in localKeys) {
          final id = key.replaceFirst('local_open_session_', '');
          if (!openedIdsFromDb.contains(id)) {
            await prefs.remove(key);
          }
        }
      } else {
        await _clearAllLocalOpenSessions();
      }

      for (int i = 0; i < _realClasses.length; i++) {
        final c = _realClasses[i];
        final session = _activeSessionData[c.id];

        if (session == null) {
          _realClasses[i] = c.copyWith(
            isAttendanceOpen: false,
            attendanceDuration: 0,
            attendanceStartTime: null,
            attendanceEndTime: null,
          );
          continue;
        }

        _realClasses[i] = c.copyWith(
          isAttendanceOpen: true,
          attendanceDuration: _calculateAttendanceMinutes(
            session['startTime'],
            session['endTime'],
          ),
          attendanceStartTime: session['startTime']?.toString(),
          attendanceEndTime: session['endTime']?.toString(),
          roomId: c.roomId ?? _getSessionLocationId(session)?.toString(),
        );

        _scheduleAutoClose(c.id);
      }

      _sortClasses();
    } catch (e) {
      debugPrint('FETCH CLASSES ERROR -> $e');
      _realClasses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _hasOtherOpenedClass(String currentClassId) {
    return _realClasses.any(
          (c) => c.id != currentClassId && c.isAttendanceOpen,
    );
  }

  Future<void> toggleAttendance(String classId, int minutes) async {
    final index = _realClasses.indexWhere((c) => c.id == classId);
    if (index == -1) throw Exception('Không tìm thấy lớp');

    final current = _realClasses[index];

    if (!current.isAttendanceOpen) {
      if (_hasOtherOpenedClass(classId)) {
        throw Exception(
          'Bạn đang mở điểm danh cho lớp khác. Hãy đóng phiên hiện tại trước.',
        );
      }

      await _openAttendanceSession(classId, current, minutes);
      await Future.delayed(const Duration(milliseconds: 250));
      await fetchClasses();
    } else {
      final session =
          _activeSessionData[classId] ?? await _loadLocalOpenSession(classId);

      if (session == null) {
        await _forceCloseClassLocal(classId);
        await fetchClasses();
        return;
      }

      await _closeSessionInternal(
        classId: classId,
        current: current,
        sessionData: session,
      );

      await Future.delayed(const Duration(milliseconds: 250));
      await fetchClasses();
    }
  }

  Future<void> _openAttendanceSession(
      String classId,
      AppClassModel current,
      int minutes,
      ) async {
    if (minutes <= 0) {
      throw Exception('Thời gian mở điểm danh phải lớn hơn 0 phút.');
    }

    final headers = await _getHeaders();

    final classroomId = _parsePositiveInt(classId);
    if (classroomId == null) {
      throw Exception('ClassId không hợp lệ: $classId');
    }

    final locationId = _getClassLocationId(current);
    if (locationId == null) {
      throw Exception('Hãy Set Location trước khi mở điểm danh.');
    }

    final now = DateTime.now();
    final end = now.add(Duration(minutes: minutes));

    final body = {
      'title': 'Attendance - ${current.className}',
      'startTime': now.toIso8601String(),
      'endTime': end.toIso8601String(),
      'status': 'OPEN',
      'classId': classroomId,
      'classroomId': classroomId,
      'locationId': locationId,
    };

    debugPrint('OPEN SESSION BODY -> ${jsonEncode(body)}');

    final res = await http.post(
      Uri.parse('$_baseUrl/sessions'),
      headers: headers,
      body: jsonEncode(body),
    );

    debugPrint('OPEN SESSION STATUS -> ${res.statusCode}');
    debugPrint('OPEN SESSION BODY -> ${utf8.decode(res.bodyBytes)}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_extractErrorMessage(res, 'Mở điểm danh thất bại'));
    }

    Map<String, dynamic> created = {};

    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map) {
        final data = decoded['data'];
        created = data is Map
            ? Map<String, dynamic>.from(data)
            : Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    final sessionId =
        created['sessionId'] ?? created['id'] ?? created['attendanceSessionId'];

    final localSession = {
      'sessionId': sessionId,
      'locationId': locationId,
      'title': body['title'],
      'startTime': body['startTime'],
      'endTime': body['endTime'],
    };

    _activeSessionData[classId] = localSession;
    await _saveLocalOpenSession(classId, localSession);

    final idx = _realClasses.indexWhere((c) => c.id == classId);
    if (idx != -1) {
      _realClasses[idx] = _realClasses[idx].copyWith(
        isAttendanceOpen: true,
        attendanceDuration: minutes,
        attendanceStartTime: now.toIso8601String(),
        attendanceEndTime: end.toIso8601String(),
        roomId: locationId.toString(),
      );
    }

    _sortClasses();
    notifyListeners();
    _scheduleAutoClose(classId);
  }

  Future<void> _closeSessionInternal({
    required String classId,
    required AppClassModel current,
    required Map<String, dynamic> sessionData,
  }) async {
    final headers = await _getHeaders();

    final sessionId =
        sessionData['sessionId'] ?? sessionData['id'] ?? sessionData['attendanceSessionId'];

    if (sessionId == null || sessionId.toString().isEmpty) {
      await _forceCloseClassLocal(classId);
      return;
    }

    final classroomId = _parsePositiveInt(classId);
    if (classroomId == null) {
      throw Exception('ClassId không hợp lệ: $classId');
    }

    final locationId =
        _getSessionLocationId(sessionData) ?? _getClassLocationId(current);

    final body = {
      'title': sessionData['title'] ?? 'Attendance - ${current.className}',
      'startTime': sessionData['startTime'] ??
          current.attendanceStartTime ??
          DateTime.now().toIso8601String(),
      'endTime': DateTime.now().toIso8601String(),
      'status': 'CLOSED',
      'classId': classroomId,
      'classroomId': classroomId,
      if (locationId != null) 'locationId': locationId,
    };

    debugPrint('CLOSE SESSION BODY -> ${jsonEncode(body)}');

    final res = await http.put(
      Uri.parse('$_baseUrl/sessions/$sessionId'),
      headers: headers,
      body: jsonEncode(body),
    );

    debugPrint('CLOSE SESSION STATUS -> ${res.statusCode}');
    debugPrint('CLOSE SESSION BODY -> ${utf8.decode(res.bodyBytes)}');

    if (res.statusCode != 200 &&
        res.statusCode != 201 &&
        res.statusCode != 204) {
      throw Exception(_extractErrorMessage(res, 'Đóng điểm danh thất bại'));
    }

    await _forceCloseClassLocal(classId);
  }

  Future<void> _closeSessionByRawData(
      String classId,
      Map<String, dynamic> raw, {
        bool silent = false,
      }) async {
    try {
      final sessionId = raw['sessionId'] ?? raw['id'] ?? raw['attendanceSessionId'];

      if (sessionId == null || sessionId.toString().isEmpty) {
        await _forceCloseClassLocal(classId);
        return;
      }

      final classroomId = _parsePositiveInt(classId);
      if (classroomId == null) {
        await _forceCloseClassLocal(classId);
        return;
      }

      final locationId = _parsePositiveInt(
        raw['locationId'] ??
            (raw['location'] is Map ? raw['location']['id'] : null),
      );

      final headers = await _getHeaders();

      final body = {
        'title': raw['title'] ?? 'Attendance',
        'startTime': raw['startTime'] ??
            raw['startDateTime'] ??
            DateTime.now().toIso8601String(),
        'endTime': DateTime.now().toIso8601String(),
        'status': 'CLOSED',
        'classId': classroomId,
        'classroomId': classroomId,
        if (locationId != null) 'locationId': locationId,
      };

      final res = await http.put(
        Uri.parse('$_baseUrl/sessions/$sessionId'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 204) {
        await _forceCloseClassLocal(classId);
      } else {
        throw Exception(_extractErrorMessage(res, 'Đóng session hết hạn thất bại'));
      }
    } catch (e) {
      if (!silent) rethrow;
      debugPrint('AUTO CLOSE RAW SESSION ERROR -> $e');
    }
  }

  Future<void> _forceCloseClassLocal(String classId) async {
    _cancelTimer(classId);
    _activeSessionData.remove(classId);
    await _removeLocalOpenSession(classId);

    final idx = _realClasses.indexWhere((c) => c.id == classId);
    if (idx != -1) {
      _realClasses[idx] = _realClasses[idx].copyWith(
        isAttendanceOpen: false,
        attendanceDuration: 0,
        attendanceStartTime: null,
        attendanceEndTime: null,
      );
    }

    _sortClasses();
    notifyListeners();
  }

  void _scheduleAutoClose(String classId) {
    _cancelTimer(classId);

    final c = _realClasses.cast<AppClassModel?>().firstWhere(
          (x) => x?.id == classId,
      orElse: () => null,
    );

    if (c == null) return;

    final end = c.attendanceEndDateTime;
    if (end == null) return;

    final remain = end.difference(DateTime.now());

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
      final session = _activeSessionData[classId];
      final idx = _realClasses.indexWhere((c) => c.id == classId);

      if (session != null && idx != -1) {
        await _closeSessionInternal(
          classId: classId,
          current: _realClasses[idx],
          sessionData: session,
        );
      } else {
        await _forceCloseClassLocal(classId);
      }

      await fetchClasses();
    } finally {
      _closingClassIds.remove(classId);
    }
  }

  Future<void> deleteClass(String classId) async {
    final headers = await _getHeaders();

    final res = await http.delete(
      Uri.parse('$_baseUrl/classrooms/$classId'),
      headers: headers,
    );

    if (res.statusCode == 200 || res.statusCode == 204) {
      _realClasses.removeWhere((c) => c.id == classId);
      _cancelTimer(classId);
      _activeSessionData.remove(classId);
      await _removeLocalOpenSession(classId);
      notifyListeners();
    } else {
      throw Exception(_extractErrorMessage(res, 'Xóa thất bại'));
    }
  }

  Future<void> updateClass(AppClassModel updated) async {
    final idx = _realClasses.indexWhere((c) => c.id == updated.id);

    if (idx != -1) {
      _realClasses[idx] = updated;
      notifyListeners();
    }

    await fetchClasses();
  }

  String getRemainingTimeText(AppClassModel c) {
    final remain = c.remainingAttendanceTime;

    if (!c.isAttendanceOpen) return 'Đã đóng';
    if (remain == null) return 'Không rõ';
    if (remain == Duration.zero) return 'Đã hết giờ';

    final h = remain.inHours;
    final m = remain.inMinutes.remainder(60);
    final s = remain.inSeconds.remainder(60);

    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }
}