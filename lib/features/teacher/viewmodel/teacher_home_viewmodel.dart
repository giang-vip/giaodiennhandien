import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';

class TeacherHomeViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int totalClasses = 0;
  int openClasses = 0;

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final payload = token.split('.')[1];
      return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      );
    } catch (e) {
      return {};
    }
  }

  Future<bool> _isTokenValid(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = _decodeJwt(token);

    print("JWT DECODED: $jwt");

    if (jwt['type'] != 'access') {
      print("❌ TOKEN TYPE INVALID");
      await prefs.clear();
      return false;
    }

    final exp = jwt['exp'];
    if (exp != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now >= exp) {
        print("❌ TOKEN EXPIRED");
        await prefs.clear();
        return false;
      }
    }

    return true;
  }

  List _safeList(dynamic data) {
    try {
      if (data is List) return data;

      if (data is Map) {
        if (data['data'] != null) {
          if (data['data'] is Map && data['data']['content'] != null) {
            return data['data']['content'];
          }
          if (data['data'] is List) {
            return data['data'];
          }
        }

        if (data['content'] != null) {
          return data['content'];
        }
      }
    } catch (_) {}

    return [];
  }

  Future<void> fetchDashboardData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      print("TOKEN READ IN HOME: $token");

      if (token == null || token.isEmpty) {
        print("❌ NO TOKEN");
        totalClasses = 0;
        openClasses = 0;
        return;
      }

      final isValid = await _isTokenValid(token);
      if (!isValid) {
        print("❌ TOKEN INVALID OR EXPIRED");
        totalClasses = 0;
        openClasses = 0;
        return;
      }

      final jwtData = _decodeJwt(token);
      final String myTeacherId = jwtData['sub']?.toString() ?? '';

      print("✅ TOKEN OK");
      print("TEACHER ID: $myTeacherId");

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final classResponse = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
        headers: headers,
      );

      final sessionResponse = await http.get(
        Uri.parse('$_baseUrl/sessions?page=0&size=50'),
        headers: headers,
      );

      print("CLASS STATUS: ${classResponse.statusCode}");
      print("SESSION STATUS: ${sessionResponse.statusCode}");

      // Chỉ clear token nếu API classrooms cũng 401
      if (classResponse.statusCode == 401) {
        print("❌ CLASS API 401 -> CLEAR TOKEN");
        await prefs.clear();
        totalClasses = 0;
        openClasses = 0;
        return;
      }

      if (classResponse.statusCode == 200) {
        final classData = jsonDecode(utf8.decode(classResponse.bodyBytes));
        final List classContent = _safeList(classData);

        print("CLASS CONTENT LENGTH: ${classContent.length}");

        final myClasses = classContent.where((item) {
          return item['teacherId']?.toString() == myTeacherId;
        }).toList();

        totalClasses = myClasses.length;

        final List<String> myClassIds = myClasses
            .map((c) => (c['id'] ?? c['classId']).toString())
            .toList();

        final Set<String> uniqueOpenClasses = {};

        // Nếu sessions 200 thì tính openClasses
        if (sessionResponse.statusCode == 200) {
          final sessionData = jsonDecode(utf8.decode(sessionResponse.bodyBytes));
          final List sessionContent = _safeList(sessionData);

          print("SESSION CONTENT LENGTH: ${sessionContent.length}");

          for (var session in sessionContent) {
            final status = session['status']?.toString().toUpperCase();

            if (status == 'OPEN' || status == '1') {
              final sClassId =
                  session['classroomId']?.toString() ??
                      session['classRoomId']?.toString() ??
                      session['classId']?.toString() ??
                      session['classRoom']?['id']?.toString() ??
                      session['classRoom']?['classId']?.toString();

              if (sClassId != null && myClassIds.contains(sClassId)) {
                uniqueOpenClasses.add(sClassId);
              }
            }
          }

          openClasses = uniqueOpenClasses.length;
        } else {
          // sessions lỗi thì không clear token, chỉ cho openClasses = 0
          print("⚠ SESSION API ERROR: ${sessionResponse.statusCode}");
          openClasses = 0;
        }

        print("TOTAL CLASSES: $totalClasses");
        print("OPEN CLASSES: $openClasses");
      } else {
        print("❌ CLASS API ERROR: ${classResponse.statusCode}");
        totalClasses = 0;
        openClasses = 0;
      }
    } catch (e) {
      print("LỖI DATA DASHBOARD: $e");
      totalClasses = 0;
      openClasses = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}