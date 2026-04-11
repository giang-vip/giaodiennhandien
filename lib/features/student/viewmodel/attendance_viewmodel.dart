import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';

class AttendanceViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;
  final String _aiBaseUrl = ApiConstants.aiBaseUrl;

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

  double _toDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  Future<void> fetchCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Vui lòng bật GPS (Vị trí) trên điện thoại.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Bạn đã từ chối quyền truy cập vị trí.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Quyền vị trí bị từ chối vĩnh viễn, hãy vào Cài đặt để mở lại.',
      );
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
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

  Future<Map<String, double>> _fetchClassLocation(
      int locationId,
      String token,
      ) async {
    try {
      var response = await http.get(
        Uri.parse('$_baseUrl/locations/$locationId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 404) {
        response = await http.get(
          Uri.parse('$_baseUrl/location/$locationId'),
          headers: {'Authorization': 'Bearer $token'},
        );
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final dataObj =
        (responseData is Map && responseData['data'] is Map<String, dynamic>)
            ? responseData['data'] as Map<String, dynamic>
            : Map<String, dynamic>.from(responseData);

        final double lat = _toDouble(
          dataObj['latitude'] ?? dataObj['lat'],
        );
        final double lon = _toDouble(
          dataObj['longitude'] ?? dataObj['lng'] ?? dataObj['lon'],
        );
        final double radius = _toDouble(
          dataObj['radiusMeters'] ?? dataObj['radius'],
          defaultValue: 50.0,
        );

        return {
          "lat": lat,
          "lon": lon,
          "radius": radius <= 0 ? 50.0 : radius,
        };
      } else {
        throw Exception(
          "API lấy vị trí trả về lỗi ${response.statusCode}.",
        );
      }
    } catch (e) {
      throw Exception("Lỗi lấy tọa độ lớp: $e");
    }
  }

  Future<void> prepareLocationCheck(int locationId) async {
    if (locationId == 0) {
      throw Exception("Buổi học này chưa được cấu hình vị trí điểm danh!");
    }

    _isCheckingLocation = true;
    _locationStatusMessage = 'Đang lấy vị trí hiện tại và so sánh...';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      if (token.isEmpty) {
        throw Exception("Không tìm thấy access_token. Vui lòng đăng nhập lại.");
      }

      _classLocation = await _fetchClassLocation(locationId, token);

      if (_classLocation!["lat"] == 0.0 || _classLocation!["lon"] == 0.0) {
        throw Exception("Phòng học này chưa được admin cài đặt tọa độ!");
      }

      _allowedRadius = _classLocation!["radius"] ?? 50.0;

      await fetchCurrentLocation();

      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _classLocation!["lat"]!,
        _classLocation!["lon"]!,
      );

      _distanceToClass = distance;
      _isWithinAllowedArea = distance <= (_allowedRadius ?? 50.0);

      if (_isWithinAllowedArea == true) {
        _locationStatusMessage =
        'Bạn đang ở đúng vị trí điểm danh.\n'
            'Khoảng cách: ${distance.toStringAsFixed(1)} m';
      } else {
        _locationStatusMessage =
        'Bạn chưa ở đúng vị trí admin đã đặt.\n'
            'Khoảng cách hiện tại: ${distance.toStringAsFixed(1)} m';
      }
    } catch (e) {
      _isWithinAllowedArea = false;
      _distanceToClass = null;
      _locationStatusMessage = e.toString().replaceAll("Exception: ", "");
      rethrow;
    } finally {
      _isCheckingLocation = false;
      notifyListeners();
    }
  }

  Future<bool> checkIn(
      int sessionId,
      int locationId,
      String currentStudentId,
      ) async {
    if (_selectedImage == null || _currentPosition == null) {
      throw Exception("Vui lòng chụp ảnh khuôn mặt trước!");
    }

    if (_isWithinAllowedArea != true) {
      throw Exception(
        "Bạn chưa ở đúng vị trí admin đã đặt, không thể tiếp tục điểm danh!",
      );
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      if (token.isEmpty) {
        throw Exception("Không tìm thấy access_token. Vui lòng đăng nhập lại.");
      }

      final classLoc =
          _classLocation ?? await _fetchClassLocation(locationId, token);

      if (classLoc["lat"] == 0.0 || classLoc["lon"] == 0.0) {
        throw Exception("Phòng học này chưa được cài đặt tọa độ!");
      }

      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        classLoc["lat"]!,
        classLoc["lon"]!,
      );

      final radius = classLoc["radius"] ?? 50.0;

      if (distance > radius) {
        _distanceToClass = distance;
        _allowedRadius = radius;
        _isWithinAllowedArea = false;
        _locationStatusMessage =
        'Bạn đã ra ngoài khu vực điểm danh.\n'
            'Khoảng cách hiện tại: ${distance.toStringAsFixed(1)} m';
        notifyListeners();
        throw Exception(
          "Bạn không ở trong vùng điểm danh cho phép!",
        );
      }

      final imageBytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final aiResponse = await http.post(
        Uri.parse('$_aiBaseUrl/verify'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "studentId": currentStudentId,
          "userLat": _currentPosition!.latitude,
          "userLon": _currentPosition!.longitude,
          "classLat": classLoc["lat"],
          "classLon": classLoc["lon"],
          "radius": classLoc["radius"],
          "image": base64Image,
        }),
      );

      if (aiResponse.statusCode == 200) {
        final aiData = jsonDecode(aiResponse.body);
        if (aiData['isSuccess'] != true) {
          throw Exception(aiData['message'] ?? 'AI xác thực thất bại');
        }
      } else {
        throw Exception(
          "Không thể kết nối AI Server (Lỗi ${aiResponse.statusCode})",
        );
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/attendance/checkin'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['sessionId'] = sessionId.toString();
      request.fields['gpsLat'] = _currentPosition!.latitude.toString();
      request.fields['gpsLng'] = _currentPosition!.longitude.toString();

      final multipartFile = await http.MultipartFile.fromPath(
        'faceImage',
        _selectedImage!.path,
      );
      request.files.add(multipartFile);

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception("Lỗi Backend: $responseData");
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
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
    _locationStatusMessage = 'Đang chờ kiểm tra vị trí...';
    notifyListeners();
  }
}