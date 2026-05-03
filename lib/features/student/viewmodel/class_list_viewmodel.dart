import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/models/app_models.dart';

class ClassListViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;
  static const int _maxStudentsPerClass = 75;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AppClassModel> _availableClasses = [];
  List<AppClassModel> get availableClasses => _availableClasses;

  final Map<String, int> _acceptedCounts = {};
  final Map<String, bool> _countKnown = {};
  final Map<String, bool> _attendanceOpenMap = {};

  String _openedAttendanceClassId = '';
  String get openedAttendanceClassId => _openedAttendanceClassId;

  String _lastActionMessage = '';
  String get lastActionMessage => _lastActionMessage;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ??
        prefs.getString('token') ??
        prefs.getString('jwt') ??
        prefs.getString('accessToken');
  }

  int _getMyStudentId(String token) {
    try {
      final payload = token.split('.')[1];
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      );
      return int.tryParse(decoded['sub'].toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  List<dynamic> _safeList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data['content'] is List) return data['content'];
      if (data['data'] is List) return data['data'];
      if (data['result'] is List) return data['result'];
      if (data['items'] is List) return data['items'];

      if (data['data'] is Map && data['data']['content'] is List) {
        return data['data']['content'];
      }

      if (data['result'] is Map && data['result']['content'] is List) {
        return data['result']['content'];
      }
    }

    return [];
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _getClassIdFromRegistration(Map<String, dynamic> m) {
    final nested = m['classroom'] ??
        m['classRoom'] ??
        m['class'] ??
        m['classes'] ??
        m['appClass'] ??
        m['clazz'];

    if (nested is Map) {
      final id = _text(
        nested['id'] ??
            nested['classId'] ??
            nested['classroomId'] ??
            nested['classRoomId'],
      );

      if (id.isNotEmpty && id != '0') return id;
    }

    return _text(
      m['classId'] ??
          m['classroomId'] ??
          m['classRoomId'] ??
          m['class_id'] ??
          m['idClass'],
    );
  }

  String _getClassIdFromClassroom(Map<String, dynamic> m) {
    return _text(
      m['id'] ?? m['classId'] ?? m['classroomId'] ?? m['classRoomId'],
    );
  }

  String _getClassIdFromSession(Map<String, dynamic> m) {
    final nested = m['classroom'] ?? m['classRoom'] ?? m['class'];

    if (nested is Map) {
      final id = _text(
        nested['id'] ??
            nested['classId'] ??
            nested['classroomId'] ??
            nested['classRoomId'],
      );

      if (id.isNotEmpty && id != '0') return id;
    }

    return _text(m['classId'] ?? m['classroomId'] ?? m['classRoomId']);
  }

  String _getRegistrationStatus(Map<String, dynamic> m) {
    final status = _text(
      m['status'] ??
          m['registrationStatus'] ??
          m['approveStatus'] ??
          m['state'],
    ).toUpperCase();

    return status.isEmpty ? 'PENDING' : status;
  }

  bool _isRegisteredStatus(String status) {
    final s = status.toUpperCase();

    return s == 'PENDING' ||
        s == 'APPROVED' ||
        s == 'ACCEPTED' ||
        s == 'APPROVE' ||
        s == 'APPROVED_BY_ADMIN';
  }

  bool _isOpenStatus(dynamic status) {
    final s = status?.toString().trim().toUpperCase() ?? '';
    return s == 'OPEN' || s == 'ACTIVE' || s == 'ONGOING' || s == '1';
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    return DateTime.tryParse(raw)?.toLocal();
  }

  bool _isSessionStillOpen(Map<String, dynamic> session) {
    if (!_isOpenStatus(session['status'])) return false;

    final end = _parseDateTime(
      session['endTime'] ??
          session['endDateTime'] ??
          session['attendanceEndTime'],
    );

    if (end == null) return true;

    return DateTime.now().isBefore(end);
  }

  int? _extractAcceptedCount(Map<String, dynamic> item) {
    const keys = [
      'acceptedStudentCount',
      'acceptedCount',
      'studentCount',
      'currentStudentCount',
      'memberCount',
    ];

    for (final key in keys) {
      final value = _parseInt(item[key]);
      if (value != null) return value;
    }

    return null;
  }

  int getAcceptedCount(String classId) => _acceptedCounts[classId] ?? 0;

  bool hasKnownCount(String classId) => _countKnown[classId] == true;

  bool isClassFull(String classId) {
    if (!hasKnownCount(classId)) return false;
    return getAcceptedCount(classId) >= _maxStudentsPerClass;
  }

  String getCapacityText(String classId) {
    if (hasKnownCount(classId)) {
      return 'Sĩ số: ${getAcceptedCount(classId)}/$_maxStudentsPerClass';
    }

    return 'Tối đa $_maxStudentsPerClass sinh viên';
  }

  bool isAttendanceOpen(String classId) {
    return _attendanceOpenMap[classId] == true;
  }

  bool canCheckIn(String classId) {
    return classId == _openedAttendanceClassId;
  }

  AppClassModel _mapClassModel(Map<String, dynamic> map, String classId) {
    final className = _text(map['title'] ?? map['className'] ?? map['name']);
    final teacherName = _text(
      map['teacherName'] ??
          map['teacher']?['fullName'] ??
          map['teacher']?['name'],
    );

    return AppClassModel(
      id: classId,
      teacherId: _text(map['teacherId'] ?? map['teacher']?['id']),
      className: className.isNotEmpty ? className : 'Chưa có tên lớp',
      description: _text(map['description']),
      teacherName: teacherName,
      startTime: _text(map['startDate'] ?? map['startTime']),
      endTime: _text(map['endDate'] ?? map['endTime']),
      isAttendanceOpen: false,
    );
  }

  Future<void> fetchAvailableClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Chưa đăng nhập');
      }

      final myStudentId = _getMyStudentId(token);

      if (myStudentId == 0) {
        throw Exception('Không xác định được tài khoản sinh viên');
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final registeredIds = <String>{};

      final myRegResponse = await http.get(
        Uri.parse(
          '$_baseUrl/class-registrations/$myStudentId/classes?page=0&size=100',
        ),
        headers: headers,
      );

      debugPrint('MY REG STATUS -> ${myRegResponse.statusCode}');
      debugPrint('MY REG BODY -> ${utf8.decode(myRegResponse.bodyBytes)}');

      if (myRegResponse.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(myRegResponse.bodyBytes));
        final list = _safeList(decoded);

        for (final raw in list) {
          if (raw is! Map) continue;

          final item = Map<String, dynamic>.from(raw);
          final id = _getClassIdFromRegistration(item);
          final status = _getRegistrationStatus(item);

          if (id.isNotEmpty && id != '0' && _isRegisteredStatus(status)) {
            registeredIds.add(id);
          }
        }
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=100'),
        headers: headers,
      );

      _availableClasses = [];
      _acceptedCounts.clear();
      _countKnown.clear();

      if (response.statusCode != 200) {
        throw Exception('Không tải được lớp');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final list = _safeList(decoded);

      for (final raw in list) {
        if (raw is! Map) continue;

        final map = Map<String, dynamic>.from(raw);
        final classId = _getClassIdFromClassroom(map);

        if (classId.isEmpty || classId == '0') continue;
        if (registeredIds.contains(classId)) continue;

        final count = _extractAcceptedCount(map);
        if (count != null) {
          _acceptedCounts[classId] = count;
          _countKnown[classId] = true;
        }

        _availableClasses.add(_mapClassModel(map, classId));
      }

      _openedAttendanceClassId = '';
      _attendanceOpenMap.clear();

      final sessionRes = await http.get(
        Uri.parse('$_baseUrl/sessions'),
        headers: headers,
      );

      if (sessionRes.statusCode == 200) {
        final sessionData = jsonDecode(utf8.decode(sessionRes.bodyBytes));
        final sessions = _safeList(sessionData);

        for (final raw in sessions) {
          if (raw is! Map) continue;

          final session = Map<String, dynamic>.from(raw);

          if (!_isSessionStillOpen(session)) continue;

          final classId = _getClassIdFromSession(session);

          if (classId.isNotEmpty && classId != '0') {
            _openedAttendanceClassId = classId;
            _attendanceOpenMap[classId] = true;
          }
        }
      }

      _availableClasses.sort((a, b) {
        if (a.id == _openedAttendanceClassId) return -1;
        if (b.id == _openedAttendanceClassId) return 1;

        final aFull = isClassFull(a.id);
        final bFull = isClassFull(b.id);

        if (aFull == bFull) return 0;
        return aFull ? 1 : -1;
      });
    } catch (e) {
      _lastActionMessage = e.toString().replaceAll('Exception: ', '');
      _availableClasses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerClass(String classId) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (isClassFull(classId)) {
        _lastActionMessage = 'Lớp đã đầy';
        return false;
      }

      final token = await _getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Chưa đăng nhập');
      }

      final studentId = _getMyStudentId(token);

      if (studentId == 0) {
        throw Exception('Không xác định được tài khoản sinh viên');
      }

      final classIdInt = int.tryParse(classId);

      if (classIdInt == null || classIdInt <= 0) {
        throw Exception('Mã lớp không hợp lệ');
      }

      final body = {
        'classId': classIdInt,
        'classroomId': classIdInt,
        'studentId': studentId,
      };

      debugPrint('REGISTER CLASS BODY -> ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/class-registrations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('REGISTER CLASS STATUS -> ${response.statusCode}');
      debugPrint('REGISTER CLASS RESPONSE -> ${utf8.decode(response.bodyBytes)}');

      final success = response.statusCode == 200 || response.statusCode == 201;

      if (success) {
        _lastActionMessage = 'Đăng ký thành công';
        _availableClasses.removeWhere((c) => c.id == classId);
        notifyListeners();
        return true;
      }

      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data is Map) {
          _lastActionMessage = data['message']?.toString() ??
              data['error']?.toString() ??
              'Đăng ký thất bại';
        } else {
          _lastActionMessage = 'Đăng ký thất bại';
        }
      } catch (_) {
        _lastActionMessage = 'Đăng ký thất bại';
      }

      return false;
    } catch (e) {
      _lastActionMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}