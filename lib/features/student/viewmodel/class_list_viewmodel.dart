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

  String _lastActionMessage = '';
  String get lastActionMessage => _lastActionMessage;

  int get maxStudentsPerClass => _maxStudentsPerClass;

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

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  int? _extractAcceptedCount(Map<String, dynamic> item) {
    const keys = [
      'acceptedStudentCount',
      'acceptedCount',
      'studentCount',
      'currentStudentCount',
      'currentAcceptedCount',
      'memberCount',
      'registeredCount',
      'acceptedRegistrationCount',
      'totalStudents',
      'totalStudent',
    ];

    for (final key in keys) {
      final value = _parseInt(item[key]);
      if (value != null) return value;
    }

    if (item['stats'] is Map) {
      final stats = Map<String, dynamic>.from(item['stats']);
      for (final key in keys) {
        final value = _parseInt(stats[key]);
        if (value != null) return value;
      }
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
    return 'Tối đa: $_maxStudentsPerClass sinh viên';
  }

  Future<void> fetchAvailableClasses() async {
    _isLoading = true;
    _lastActionMessage = '';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        throw Exception("Chưa đăng nhập");
      }

      final myStudentId = _getMyStudentId(token);

      final myRegResponse = await http.get(
        Uri.parse(
          '$_baseUrl/class-registrations/$myStudentId/classes?page=0&size=100',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      final Set<String> registeredIds = {};

      if (myRegResponse.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(myRegResponse.bodyBytes));
        final List list = _safeList(decoded);

        for (var item in list) {
          final cId =
              item['classId']?.toString() ??
                  item['classRoom']?['classId']?.toString() ??
                  item['classroomId']?.toString() ??
                  '0';

          final status =
              item['status']?.toString().toUpperCase().trim() ?? 'PENDING';

          if (status == 'PENDING' || status == 'ACCEPTED') {
            registeredIds.add(cId);
          }
        }
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=100'),
        headers: {'Authorization': 'Bearer $token'},
      );

      _availableClasses = [];
      _acceptedCounts.clear();
      _countKnown.clear();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List list = _safeList(decoded);

        _availableClasses = list.where((item) {
          final checkId =
              item['classId']?.toString() ?? item['id']?.toString() ?? '0';
          return !registeredIds.contains(checkId);
        }).map((item) {
          final map = Map<String, dynamic>.from(item as Map);

          final classId =
              map['classId']?.toString() ?? map['id']?.toString() ?? '0';

          final count = _extractAcceptedCount(map);
          if (count != null) {
            _acceptedCounts[classId] = count;
            _countKnown[classId] = true;
          } else {
            _acceptedCounts[classId] = 0;
            _countKnown[classId] = false;
          }

          final locationIds = map['locationIds'];
          String? roomId;
          if (locationIds is List && locationIds.isNotEmpty) {
            roomId = locationIds.first.toString();
          }

          return AppClassModel(
            id: classId,
            teacherId: map['teacherId']?.toString() ?? '0',
            className: map['title'] ?? 'Chưa có tên',
            description: map['description'] ?? 'Chưa có mô tả',
            teacherName: map['teacherName'] ?? 'Giảng viên',
            startTime: map['startDate']?.toString() ?? 'N/A',
            endTime: map['endDate']?.toString() ?? 'N/A',
            roomId: roomId,
          );
        }).toList();

        _availableClasses.sort((a, b) {
          final aFull = isClassFull(a.id);
          final bFull = isClassFull(b.id);
          if (aFull == bFull) return 0;
          return aFull ? 1 : -1;
        });
      } else if (response.statusCode == 401) {
        throw Exception("Unauthorized");
      } else {
        throw Exception("Không tải được danh sách lớp");
      }
    } catch (e) {
      _lastActionMessage = e.toString().replaceAll('Exception: ', '');
      _availableClasses = [];
      _acceptedCounts.clear();
      _countKnown.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerClass(String classId) async {
    try {
      _isLoading = true;
      _lastActionMessage = '';
      notifyListeners();

      if (isClassFull(classId)) {
        _lastActionMessage = 'Lớp đã đủ $_maxStudentsPerClass sinh viên';
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        throw Exception("Chưa đăng nhập");
      }

      final myStudentId = _getMyStudentId(token);

      final bodyData = {
        "classId": int.parse(classId),
        "studentId": myStudentId,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/class-registrations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyData),
      );

      final success = response.statusCode == 200 || response.statusCode == 201;

      if (success) {
        _lastActionMessage =
        'Đăng ký lớp thành công. Vui lòng chờ giảng viên duyệt.';
        _availableClasses.removeWhere((c) => c.id == classId);
        _acceptedCounts.remove(classId);
        _countKnown.remove(classId);
      } else {
        String message = 'Lỗi đăng ký lớp! Vui lòng thử lại.';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          }
        } catch (_) {}
        _lastActionMessage = message;
      }

      return success;
    } catch (e) {
      _lastActionMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}