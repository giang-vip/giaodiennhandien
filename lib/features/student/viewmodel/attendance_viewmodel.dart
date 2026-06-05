import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/mock_location_service.dart';

class AttendanceViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCheckingLocation = false;
  bool get isCheckingLocation => _isCheckingLocation;

  File? _selectedImage;
  File? get selectedImage => _selectedImage;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  Map<String, double>? _classLocation;

  double? _distanceToClass;
  double? get distanceToClass => _distanceToClass;

  double? _allowedRadius;
  double? get allowedRadius => _allowedRadius;

  bool? _isWithinAllowedArea;
  bool? get isWithinAllowedArea => _isWithinAllowedArea;

  String _locationStatusMessage = 'Đang chờ kiểm tra vị trí...';
  String get locationStatusMessage => _locationStatusMessage;

  int _latestLocationId = 0;
  int get latestLocationId => _latestLocationId;


  double _toDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

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

  Map<String, dynamic> _extractData(dynamic responseData) {
    if (responseData is Map && responseData['data'] is Map) {
      return Map<String, dynamic>.from(responseData['data']);
    }

    if (responseData is Map && responseData['result'] is Map) {
      return Map<String, dynamic>.from(responseData['result']);
    }

    return Map<String, dynamic>.from(responseData);
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('access_token') ??
        prefs.getString('token') ??
        prefs.getString('jwt') ??
        prefs.getString('accessToken') ??
        '';
  }

  Future<void> fetchCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Vui lòng bật GPS');

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Không có quyền vị trí');
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final isMock = await MockLocationService.isMockLocation(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    if (isMock) {
      throw Exception("Phát hiện vị trí giả lập (mock location)");
    }


    notifyListeners();
  }

  Future<void> pickImageFromCamera() async {
    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );

    if (pickedFile != null) {
      _selectedImage = File(pickedFile.path);
      notifyListeners();
    }
  }

  int _extractLocationIdFromClass(Map<String, dynamic> data) {
    final direct = _toInt(
      data['roomId'] ??
          data['locationId'] ??
          data['location_id'] ??
          data['room_id'],
    );

    if (direct > 0) return direct;

    final location = data['location'] ?? data['room'];

    if (location is Map) {
      final nestedId = _toInt(location['id'] ?? location['locationId']);
      if (nestedId > 0) return nestedId;
    }

    final locationIds = data['locationIds'];

    if (locationIds is List && locationIds.isNotEmpty) {
      final id = _toInt(locationIds.first);
      if (id > 0) return id;
    }

    final locations = data['locations'];

    if (locations is List && locations.isNotEmpty) {
      final first = locations.first;

      if (first is Map) {
        final id = _toInt(first['id'] ?? first['locationId']);
        if (id > 0) return id;
      }

      final id = _toInt(first);
      if (id > 0) return id;
    }

    return 0;
  }

  int _extractLocationIdFromSession(Map<String, dynamic> data) {
    final direct = _toInt(
      data['locationId'] ??
          data['location_id'] ??
          data['roomId'] ??
          data['room_id'],
    );

    if (direct > 0) return direct;

    final location = data['location'] ?? data['room'];

    if (location is Map) {
      final id = _toInt(location['id'] ?? location['locationId']);
      if (id > 0) return id;
    }

    return 0;
  }

  String _extractClassIdFromClass(Map<String, dynamic> data) {
    return _text(
      data['id'] ??
          data['classId'] ??
          data['classroomId'] ??
          data['classRoomId'],
    );
  }

  String _extractClassIdFromSession(Map<String, dynamic> data) {
    return _text(
      data['classroomId'] ??
          data['classId'] ??
          data['classRoomId'] ??
          data['class_id'],
    );
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

  Future<int> _fetchLatestClassLocationId({
    required String classId,
    required String token,
  }) async {
    if (classId.trim().isEmpty || classId == '0') return 0;

    final urls = [
      '$_baseUrl/classrooms/$classId',
      '$_baseUrl/classrooms?page=0&size=500',
    ];

    for (final url in urls) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        debugPrint('LATEST CLASS URL -> $url');
        debugPrint('LATEST CLASS STATUS -> ${response.statusCode}');
        debugPrint('LATEST CLASS BODY -> ${utf8.decode(response.bodyBytes)}');

        if (response.statusCode != 200) continue;

        final decoded = jsonDecode(utf8.decode(response.bodyBytes));

        if (url.contains('?')) {
          final list = _safeList(decoded);

          for (final raw in list) {
            if (raw is! Map) continue;

            final map = Map<String, dynamic>.from(raw);
            final id = _extractClassIdFromClass(map);

            if (id == classId) {
              final locationId = _extractLocationIdFromClass(map);
              if (locationId > 0) return locationId;
            }
          }
        } else {
          final data = _extractData(decoded);
          final locationId = _extractLocationIdFromClass(data);
          if (locationId > 0) return locationId;
        }
      } catch (e) {
        debugPrint('FETCH LATEST CLASS LOCATION ERROR -> $e');
      }
    }

    return 0;
  }

  Future<int> _fetchSessionLocationId({
    required int sessionId,
    required String token,
  }) async {
    if (sessionId <= 0) return 0;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sessions/$sessionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('SESSION DETAIL STATUS -> ${response.statusCode}');
      debugPrint('SESSION DETAIL BODY -> ${utf8.decode(response.bodyBytes)}');

      if (response.statusCode != 200) return 0;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final data = _extractData(decoded);

      return _extractLocationIdFromSession(data);
    } catch (e) {
      debugPrint('FETCH SESSION LOCATION ERROR -> $e');
      return 0;
    }
  }

  Future<int> _fetchOpenSessionLocationIdByClass({
    required String classId,
    required String token,
  }) async {
    if (classId.trim().isEmpty || classId == '0') return 0;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sessions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('OPEN SESSION LIST STATUS -> ${response.statusCode}');
      debugPrint('OPEN SESSION LIST BODY -> ${utf8.decode(response.bodyBytes)}');

      if (response.statusCode != 200) return 0;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final list = _safeList(decoded);

      Map<String, dynamic>? newestOpenSession;

      for (final raw in list) {
        if (raw is! Map) continue;

        final session = Map<String, dynamic>.from(raw);
        final sidClassId = _extractClassIdFromSession(session);

        if (sidClassId != classId) continue;
        if (!_isSessionStillOpen(session)) continue;

        if (newestOpenSession == null) {
          newestOpenSession = session;
          continue;
        }

        final currentStart = _parseDateTime(session['startTime']);
        final oldStart = _parseDateTime(newestOpenSession['startTime']);

        if (currentStart != null &&
            oldStart != null &&
            currentStart.isAfter(oldStart)) {
          newestOpenSession = session;
        }
      }

      if (newestOpenSession == null) return 0;

      return _extractLocationIdFromSession(newestOpenSession);
    } catch (e) {
      debugPrint('FETCH OPEN SESSION LOCATION ERROR -> $e');
      return 0;
    }
  }

  Future<int> _resolveLatestLocationId({
    required int sessionId,
    required String classId,
    required int fallbackLocationId,
    required String token,
  }) async {
    final sessionLocationId = await _fetchSessionLocationId(
      sessionId: sessionId,
      token: token,
    );

    if (sessionLocationId > 0) return sessionLocationId;

    final openSessionLocationId = await _fetchOpenSessionLocationIdByClass(
      classId: classId,
      token: token,
    );

    if (openSessionLocationId > 0) return openSessionLocationId;

    final classLocationId = await _fetchLatestClassLocationId(
      classId: classId,
      token: token,
    );

    if (classLocationId > 0) return classLocationId;

    return fallbackLocationId;
  }

  Future<Map<String, double>> _fetchClassLocation(
      int locationId,
      String token,
      ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/locations/$locationId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    debugPrint('LOCATION DETAIL ID -> $locationId');
    debugPrint('LOCATION DETAIL STATUS -> ${response.statusCode}');
    debugPrint('LOCATION DETAIL BODY -> ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode != 200) {
      throw Exception("Không lấy được location mới nhất");
    }

    final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
    final data = _extractData(jsonData);

    final lat = _toDouble(data['latitude']);
    final lon = _toDouble(data['longitude']);
    final radius = _toDouble(data['radiusMeters'], defaultValue: 50);

    if (lat == 0 || lon == 0) {
      throw Exception("Location không hợp lệ");
    }

    return {
      "lat": lat,
      "lon": lon,
      "radius": radius <= 0 ? 50 : radius,
    };
  }

  Future<int> prepareLocationCheck({
    required int sessionId,
    required String classId,
    required int fallbackLocationId,
  }) async {
    _isCheckingLocation = true;
    _isWithinAllowedArea = null;
    _locationStatusMessage = 'Đang lấy vị trí phòng mới nhất...';
    notifyListeners();

    try {
      final token = await _getToken();

      if (token.isEmpty) {
        throw Exception('Bạn chưa đăng nhập');
      }

      final latestLocationId = await _resolveLatestLocationId(
        sessionId: sessionId,
        classId: classId,
        fallbackLocationId: fallbackLocationId,
        token: token,
      );

      if (latestLocationId <= 0) {
        throw Exception('Buổi học này chưa được cấu hình phòng học');
      }

      _latestLocationId = latestLocationId;

      _classLocation = await _fetchClassLocation(latestLocationId, token);
      _allowedRadius = _classLocation!["radius"];

      await fetchCurrentLocation();

      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _classLocation!["lat"]!,
        _classLocation!["lon"]!,
      );

      _distanceToClass = distance;
      _isWithinAllowedArea = distance <= _allowedRadius!;

      _locationStatusMessage = _isWithinAllowedArea!
          ? "Đúng vị trí phòng admin đang đặt"
          : "Sai vị trí phòng admin đang đặt";

      return latestLocationId;
    } finally {
      _isCheckingLocation = false;
      notifyListeners();
    }
  }


  Future<bool> checkIn({
    required int sessionId,
    required String classId,
    required int fallbackLocationId,
    required String studentId,
  }) async {

    if (_selectedImage == null) {
      throw Exception("Chưa chụp ảnh");
    }

    // Chỉ kiểm tra vị trí
    // await prepareLocationCheck(
    //   sessionId: sessionId,
    //   classId: classId,
    //   fallbackLocationId: fallbackLocationId,
    // );
    //
    // if (_isWithinAllowedArea != true) {
    //   throw Exception("Sai vị trí phòng admin đang đặt");
    // }

    if (_isWithinAllowedArea != true) {
      throw Exception("Vui lòng kiểm tra vị trí trước khi điểm danh");
    }

    _isLoading = true;
    notifyListeners();

    try {

      // TẠM THỜI KHÔNG VERIFY FACE TRƯỚC
      // vì backend attendance/checkin đã tự gọi faceService.recognize()
      //
      // await _verifyFace(studentId);

      final token = await _getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/attendance/checkin'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.fields['sessionId'] = sessionId.toString();

      request.fields['gpsLat'] =
          _currentPosition!.latitude.toString();

      request.fields['gpsLng'] =
          _currentPosition!.longitude.toString();

      print("CheckIn sessionId: $sessionId");
      print(
        "GPS: ${_currentPosition!.latitude}, "
            "${_currentPosition!.longitude}",
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'faceImage',
          _selectedImage!.path,
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      print("CHECKIN STATUS: ${response.statusCode}");
      print("CHECKIN BODY: $body");

      if (response.statusCode == 200 ||
          response.statusCode == 201) {

        final data = jsonDecode(body);

        final name = data['name'];
        final confidence =
        (data['confidence'] as num).toDouble();

        final message = data['message'];

        print(
          "FaceResponse: "
              "$name - $confidence - $message",
        );

        if (name == "Unknown" || confidence < 0.6) {
          throw Exception(
            message ?? "Khuôn mặt không khớp",
          );
        }

        return true;
      }

      throw Exception(body);

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearData() {
    _selectedImage = null;
    _currentPosition = null;
    _classLocation = null;
    _distanceToClass = null;
    _allowedRadius = null;
    _isWithinAllowedArea = null;
    _latestLocationId = 0;
    _locationStatusMessage = 'Đang chờ kiểm tra vị trí...';
    notifyListeners();
  }
}