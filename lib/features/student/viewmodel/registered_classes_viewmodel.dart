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

  bool isClassActive(String classId) => _activeSessions.containsKey(classId);
  int? getActiveSessionId(String classId) => _activeSessions[classId];
  int? getSessionLocationId(String classId) => _sessionLocations[classId];

  int _getMyStudentId(String token) {
    try {
      final payload = token.split('.')[1];
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      );
      return int.parse(decoded['sub'].toString());
    } catch (e) {
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
      print("STUDENT ID: $myStudentId");

      final myRegResponse = await http.get(
        Uri.parse(
          '$_baseUrl/class-registrations/$myStudentId/classes?page=0&size=50',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("REG STATUS: ${myRegResponse.statusCode}");
      print("REG BODY: ${myRegResponse.body}");

      final Set<String> registeredIds = {};

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
          registeredIds.add(cId);
        }
      } else if (myRegResponse.statusCode == 401) {
        throw Exception("Token hết hạn khi lấy lớp đã đăng ký");
      } else {
        throw Exception("Không lấy được lớp đã đăng ký");
      }

      print("REGISTERED IDS: $registeredIds");

      final classResponse = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("CLASS STATUS: ${classResponse.statusCode}");
      print("CLASS BODY: ${classResponse.body}");

      _registeredClasses = [];

      if (classResponse.statusCode == 200) {
        final data = jsonDecode(utf8.decode(classResponse.bodyBytes));
        final List<dynamic> classContent = _safeList(data);

        _registeredClasses =
            classContent.where((item) {
              final checkId =
                  item['classId']?.toString() ??
                      item['id']?.toString() ??
                      '0';
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
      } else if (classResponse.statusCode == 401) {
        throw Exception("Token hết hạn khi lấy danh sách lớp");
      }

      print("REGISTERED CLASS COUNT: ${_registeredClasses.length}");

      _activeSessions.clear();
      _sessionLocations.clear();

      final sessionResponse = await http.get(
        Uri.parse('$_baseUrl/sessions?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("SESSION STATUS: ${sessionResponse.statusCode}");
      print("SESSION BODY: ${sessionResponse.body}");

      if (sessionResponse.statusCode == 200) {
        final sessionData = jsonDecode(utf8.decode(sessionResponse.bodyBytes));
        final List<dynamic> content = _safeList(sessionData);

        print("SESSION LIST LENGTH: ${content.length}");

        for (var session in content) {
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
          final sessionTitle = _normalizeText((session['title'] ?? '').toString());

          if (sClassId == null || sClassId.isEmpty || sClassId == 'null') {
            for (final c in _registeredClasses) {
              final expectedTitle =
              _normalizeText("Attendance - ${c.className}");
              if (sessionTitle == expectedTitle) {
                sClassId = c.id;
                print("MATCH SESSION BY TITLE -> classId=${c.id}, sessionId=$sId");
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
              print("MATCH SESSION BY LOCATION -> classId=${candidates.first.id}, sessionId=$sId");
            }
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

            print("ACTIVE SESSION SAVED -> classId=$sClassId, sessionId=$sId, locationId=$locId");
          } else {
            print("UNMATCHED OPEN SESSION: ${jsonEncode(session)}");
          }
        }
      } else if (sessionResponse.statusCode == 401) {
        print("SESSION 401 -> token hết hạn, không load được phiên đang mở");
      }

      print("ACTIVE SESSION MAP: $_activeSessions");
      print("SESSION LOCATION MAP: $_sessionLocations");
    } catch (e) {
      print(" LỖI MY CLASSES: $e");
      _registeredClasses = [];
      _activeSessions.clear();
      _sessionLocations.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}