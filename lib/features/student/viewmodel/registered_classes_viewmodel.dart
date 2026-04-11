import 'dart:async';
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

  List<AppClassModel> _registeredClasses = [];
  List<AppClassModel> get registeredClasses => _registeredClasses;

  final Map<String, int> _activeSessions = {};
  final Map<String, int> _sessionLocations = {};
  final Map<String, DateTime> _sessionEndTimes = {};
  final Map<String, String> _registrationStatuses = {};

  Timer? _countdownTimer;

  String getRegistrationStatus(String classId) {
    return _registrationStatuses[classId] ?? 'UNKNOWN';
  }

  bool isRegistrationAccepted(String classId) {
    return getRegistrationStatus(classId) == 'ACCEPTED';
  }

  bool isRegistrationPending(String classId) {
    return getRegistrationStatus(classId) == 'PENDING';
  }

  bool isClassActive(String classId) {
    if (!_activeSessions.containsKey(classId)) return false;

    final endTime = _sessionEndTimes[classId];
    if (endTime == null) return true;

    return DateTime.now().isBefore(endTime);
  }

  int? getActiveSessionId(String classId) => _activeSessions[classId];
  int? getSessionLocationId(String classId) => _sessionLocations[classId];

  String getRemainingTime(String classId) {
    final endTime = _sessionEndTimes[classId];
    if (endTime == null) return '';

    final diff = endTime.difference(DateTime.now());
    if (diff.inSeconds <= 0) return '00:00';

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${diff.inMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _getMyStudentId(String token) {
    try {
      final payload = token.split('.')[1];
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      );
      return int.parse(decoded['sub'].toString());
    } catch (_) {
      return 0;
    }
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

  String _normalizeText(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000).toLocal();
      }
    }

    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return null;

      final asInt = int.tryParse(raw);
      if (asInt != null) {
        if (asInt > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(asInt).toLocal();
        }
        if (asInt > 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(asInt * 1000).toLocal();
        }
      }

      try {
        return DateTime.parse(raw).toLocal();
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  DateTime? _extractSessionStartTime(Map<String, dynamic> session) {
    const keys = [
      'startTime',
      'startDate',
      'startAt',
      'openedAt',
      'openTime',
      'createdAt',
      'createdDate',
    ];

    for (final key in keys) {
      final dt = _parseDateTime(session[key]);
      if (dt != null) return dt;
    }

    return null;
  }

  int? _extractDurationMinutes(Map<String, dynamic> session) {
    const keys = [
      'durationMinutes',
      'durationMinute',
      'duration',
      'attendanceDuration',
      'attendanceDurationMinutes',
      'expireInMinutes',
      'remainingMinutes',
    ];

    for (final key in keys) {
      final value = _parseInt(session[key]);
      if (value != null && value > 0) return value;
    }

    return null;
  }

  DateTime? _extractSessionEndTime(Map<String, dynamic> session) {
    const directKeys = [
      'endTime',
      'endDate',
      'endAt',
      'expiresAt',
      'expiredAt',
      'closeTime',
      'closedAt',
      'deadline',
      'attendanceEndTime',
      'attendanceEndDate',
    ];

    for (final key in directKeys) {
      final dt = _parseDateTime(session[key]);
      if (dt != null) return dt;
    }

    final startTime = _extractSessionStartTime(session);
    final durationMinutes = _extractDurationMinutes(session);

    if (startTime != null && durationMinutes != null) {
      return startTime.add(Duration(minutes: durationMinutes));
    }

    return null;
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();

    if (_sessionEndTimes.isEmpty) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final expiredClassIds = <String>[];

      _sessionEndTimes.forEach((classId, endTime) {
        if (!now.isBefore(endTime)) {
          expiredClassIds.add(classId);
        }
      });

      for (final classId in expiredClassIds) {
        _sessionEndTimes.remove(classId);
        _activeSessions.remove(classId);
        _sessionLocations.remove(classId);
      }

      notifyListeners();
    });
  }

  Future<void> fetchRegisteredClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        throw Exception("Không tìm thấy access_token");
      }

      final myStudentId = _getMyStudentId(token);

      final myRegResponse = await http.get(
        Uri.parse(
          '$_baseUrl/class-registrations/$myStudentId/classes?page=0&size=100',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      final Set<String> registeredIds = {};
      _registrationStatuses.clear();

      if (myRegResponse.statusCode == 200) {
        final rawRegData = jsonDecode(utf8.decode(myRegResponse.bodyBytes));
        final List<dynamic> myRegData = _safeList(rawRegData);

        for (var item in myRegData) {
          final cId =
              item['classId']?.toString() ??
                  item['classRoom']?['classId']?.toString() ??
                  item['classroomId']?.toString() ??
                  item['classRoom']?['id']?.toString() ??
                  '0';

          final status =
              item['status']?.toString().toUpperCase().trim() ?? 'PENDING';

          if (status == 'PENDING' || status == 'ACCEPTED') {
            registeredIds.add(cId);
            _registrationStatuses[cId] = status;
          }
        }
      } else if (myRegResponse.statusCode == 401) {
        throw Exception("Token hết hạn khi lấy lớp đã đăng ký");
      } else {
        throw Exception("Không lấy được lớp đã đăng ký");
      }

      final classResponse = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=100'),
        headers: {'Authorization': 'Bearer $token'},
      );

      _registeredClasses = [];

      if (classResponse.statusCode == 200) {
        final data = jsonDecode(utf8.decode(classResponse.bodyBytes));
        final List<dynamic> classContent = _safeList(data);

        _registeredClasses = classContent.where((item) {
          final checkId =
              item['classId']?.toString() ?? item['id']?.toString() ?? '0';
          return registeredIds.contains(checkId);
        }).map((item) {
          final locationIds = item['locationIds'];
          String? roomId;
          if (locationIds is List && locationIds.isNotEmpty) {
            roomId = locationIds.first.toString();
          }

          return AppClassModel(
            id: item['classId']?.toString() ?? item['id']?.toString() ?? '0',
            teacherId: item['teacherId']?.toString() ?? '0',
            className: item['title'] ?? 'Chưa có tên',
            description: item['description'] ?? 'Chưa có mô tả',
            teacherName: item['teacherName'] ?? 'Giảng viên',
            startTime: item['startDate']?.toString() ?? 'N/A',
            endTime: item['endDate']?.toString() ?? 'N/A',
            roomId: roomId,
          );
        }).toList();

        _registeredClasses.sort((a, b) {
          final sa = getRegistrationStatus(a.id);
          final sb = getRegistrationStatus(b.id);

          int order(String s) {
            switch (s) {
              case 'ACCEPTED':
                return 0;
              case 'PENDING':
                return 1;
              default:
                return 2;
            }
          }

          return order(sa).compareTo(order(sb));
        });
      } else if (classResponse.statusCode == 401) {
        throw Exception("Token hết hạn khi lấy danh sách lớp");
      }

      _activeSessions.clear();
      _sessionLocations.clear();
      _sessionEndTimes.clear();

      final sessionResponse = await http.get(
        Uri.parse('$_baseUrl/sessions?page=0&size=100'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (sessionResponse.statusCode == 200) {
        final sessionData = jsonDecode(utf8.decode(sessionResponse.bodyBytes));
        final List<dynamic> content = _safeList(sessionData);

        for (var rawSession in content) {
          if (rawSession is! Map) continue;
          final session = Map<String, dynamic>.from(rawSession);

          final status = session['status']?.toString().toUpperCase();
          if (status != 'OPEN' &&
              status != '1' &&
              status != 'ACTIVE' &&
              status != 'ONGOING') {
            continue;
          }

          String? sClassId =
              session['classroomId']?.toString() ??
                  session['classRoomId']?.toString() ??
                  session['classId']?.toString() ??
                  session['classRoom']?['id']?.toString() ??
                  session['classRoom']?['classId']?.toString() ??
                  session['classroom']?['id']?.toString() ??
                  session['classroom']?['classId']?.toString();

          final sId = session['sessionId'] ?? session['id'];
          final locId = session['locationId'];
          final sessionTitle =
          _normalizeText((session['title'] ?? '').toString());

          if (sClassId == null || sClassId.isEmpty || sClassId == 'null') {
            for (final c in _registeredClasses) {
              final expectedTitle = _normalizeText("Attendance - ${c.className}");
              if (sessionTitle == expectedTitle) {
                sClassId = c.id;
                break;
              }
            }
          }

          if ((sClassId == null || sClassId.isEmpty || sClassId == 'null') &&
              locId != null) {
            final candidates = _registeredClasses
                .where((c) => c.roomId == locId.toString())
                .toList();

            if (candidates.length == 1) {
              sClassId = candidates.first.id;
            }
          }

          final endTime = _extractSessionEndTime(session);

          if (endTime != null && !DateTime.now().isBefore(endTime)) {
            continue;
          }

          if (sClassId != null &&
              sClassId.isNotEmpty &&
              sClassId != 'null' &&
              sId != null) {
            _activeSessions[sClassId] = int.tryParse(sId.toString()) ?? 0;

            if (locId != null) {
              _sessionLocations[sClassId] =
                  int.tryParse(locId.toString()) ?? 0;
            }

            if (endTime != null) {
              _sessionEndTimes[sClassId] = endTime;
            }
          }
        }
      } else if (sessionResponse.statusCode == 401) {
        throw Exception("Token hết hạn khi lấy phiên điểm danh");
      }

      _startCountdownTimer();
    } catch (e) {
      _registeredClasses = [];
      _activeSessions.clear();
      _sessionLocations.clear();
      _sessionEndTimes.clear();
      _registrationStatuses.clear();
      _countdownTimer?.cancel();
      debugPrint("LỖI MY CLASSES: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}