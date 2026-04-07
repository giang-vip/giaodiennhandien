import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/app_models.dart';

class ClassListViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AppClassModel> _availableClasses = [];
  List<AppClassModel> get availableClasses => _availableClasses;

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

  Future<void> fetchAvailableClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        throw Exception("Chưa đăng nhập");
      }

      final myStudentId = _getMyStudentId(token);
      print("STUDENT ID FETCH AVAILABLE: $myStudentId");

      // B1: lấy danh sách lớp đã đăng ký của sinh viên
      final myRegResponse = await http.get(
        Uri.parse('$_baseUrl/class-registrations/student/$myStudentId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("REG STATUS: ${myRegResponse.statusCode}");
      print("REG BODY: ${myRegResponse.body}");

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
          registeredIds.add(cId);
        }
      }

      print("REGISTERED IDS: $registeredIds");

      // B2: lấy tất cả lớp và lọc ra các lớp chưa đăng ký
      final response = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("CLASS LIST STATUS: ${response.statusCode}");
      print("CLASS LIST BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List list = _safeList(decoded);

        _availableClasses = list.where((item) {
          final checkId =
              item['classId']?.toString() ??
                  item['id']?.toString() ??
                  '0';
          return !registeredIds.contains(checkId);
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

        print("AVAILABLE CLASS COUNT: ${_availableClasses.length}");
      } else if (response.statusCode == 401) {
        throw Exception("Unauthorized");
      } else {
        throw Exception("Không tải được danh sách lớp");
      }
    } catch (e) {
      print("FETCH AVAILABLE CLASSES ERROR: $e");
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

      print("REGISTER BODY: ${jsonEncode(bodyData)}");

      final response = await http.post(
        Uri.parse('$_baseUrl/class-registrations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyData),
      );

      print("REGISTER STATUS: ${response.statusCode}");
      print("REGISTER RESPONSE: ${response.body}");

      final success = response.statusCode == 200 || response.statusCode == 201;

      if (success) {
        _availableClasses.removeWhere((c) => c.id == classId);
      }

      return success;
    } catch (e) {
      print("REGISTER ERROR: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}