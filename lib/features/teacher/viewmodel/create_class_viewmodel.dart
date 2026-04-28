import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/models/RoomModel.dart';

class CreateClassViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLocationLoading = false;
  bool get isLocationLoading => _isLocationLoading;

  List<RoomModel> _locations = [];
  List<RoomModel> get locations => _locations;

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final payload = token.split('.')[1];
      return jsonDecode(
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(payload),
          ),
        ),
      );
    } catch (e) {
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

  Future<bool> _isTokenValid(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = _decodeJwt(token);

    if (jwt['type'] != null && jwt['type'] != 'access') {
      await prefs.clear();
      return false;
    }

    final exp = jwt['exp'];
    if (exp != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now >= exp) {
        await prefs.clear();
        return false;
      }
    }

    return true;
  }

  List _safeList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data['content'] is List) return data['content'];
      if (data['data'] is List) return data['data'];
      if (data['result'] is List) return data['result'];

      if (data['data'] is Map) {
        final inner = data['data'];
        if (inner['content'] is List) return inner['content'];
        if (inner['data'] is List) return inner['data'];
        if (inner['result'] is List) return inner['result'];
      }
    }

    return [];
  }

  String _buildLocationName(Map<String, dynamic> item) {
    final code = item['locationCode'] ??
        item['code'] ??
        item['roomCode'] ??
        item['name'] ??
        item['roomName'] ??
        'Phòng';

    final address = item['address'] ??
        item['locationName'] ??
        item['description'] ??
        item['floor'] ??
        '';

    if (address.toString().trim().isEmpty) {
      return code.toString();
    }

    return '$code - $address';
  }

  // ================= LẤY DANH SÁCH PHÒNG / VỊ TRÍ =================
  Future<void> fetchLocations() async {
    _isLocationLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        print('LOCATION ERROR: NO TOKEN');
        _locations = [];
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/locations?page=0&size=100'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('LOCATION STATUS: ${response.statusCode}');
      print('LOCATION BODY: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final list = _safeList(data);

        _locations = list.map((raw) {
          final item = Map<String, dynamic>.from(raw);

          final id = item['locationId']?.toString() ??
              item['id']?.toString() ??
              item['roomId']?.toString() ??
              '';

          return RoomModel(
            id: id,
            name: _buildLocationName(item),
          );
        }).where((room) => room.id.isNotEmpty).toList();
      } else {
        _locations = [];
      }
    } catch (e) {
      print('LOCATION ERROR: $e');
      _locations = [];
    } finally {
      _isLocationLoading = false;
      notifyListeners();
    }
  }

  // ================= TẠO LỚP =================
  Future<bool> createClassAPI({
    required String title,
    required String description,
    required int locationId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final token = await _getToken();

      if (token == null || token.isEmpty) {
        print('NO TOKEN');
        return false;
      }

      final isValid = await _isTokenValid(token);
      if (!isValid) {
        print('TOKEN INVALID');
        return false;
      }

      final jwtData = _decodeJwt(token);
      final sub = jwtData['sub'];

      if (sub == null) {
        print('TOKEN KHÔNG CÓ SUB');
        return false;
      }

      final int myTeacherId = int.tryParse(sub.toString()) ?? 0;

      if (myTeacherId == 0) {
        print('TEACHER ID INVALID');
        return false;
      }

      final body = {
        'teacherId': myTeacherId,
        'title': title,
        'description': description,
        'startDate': startDate,
        'endDate': endDate,
        'locationIds': [locationId],
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/classrooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('CREATE STATUS: ${response.statusCode}');
      print('CREATE BODY: ${response.body}');
      print('CREATE REQUEST BODY: ${jsonEncode(body)}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('CREATE SUCCESS');
        return true;
      }

      print('CREATE FAIL');
      return false;
    } catch (e) {
      print('CREATE CLASS ERROR: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
