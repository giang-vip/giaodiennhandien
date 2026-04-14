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

  /// 🔥 FIX: parse response linh hoạt
  Map<String, dynamic> _extractData(dynamic responseData) {
    if (responseData is Map && responseData['data'] != null) {
      return Map<String, dynamic>.from(responseData['data']);
    }
    return Map<String, dynamic>.from(responseData);
  }

  Future<void> fetchCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Vui lòng bật GPS');
    }

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

  /// 🔥 FIX CỰC QUAN TRỌNG
  Future<Map<String, double>> _fetchClassLocation(
      int locationId,
      String token,
      ) async {

    print("CALL API LOCATION ID = $locationId");

    final response = await http.get(
      Uri.parse('$_baseUrl/locations/$locationId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (response.statusCode != 200) {
      throw Exception("Không lấy được location");
    }

    final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
    final data = _extractData(jsonData);

    final lat = _toDouble(data['latitude']);
    final lon = _toDouble(data['longitude']);
    final radius = _toDouble(data['radiusMeters'], defaultValue: 50);

    print("PARSED LOCATION: lat=$lat, lon=$lon, radius=$radius");

    if (lat == 0 || lon == 0) {
      throw Exception("Location chưa có tọa độ!");
    }

    return {
      "lat": lat,
      "lon": lon,
      "radius": radius <= 0 ? 50 : radius,
    };
  }

  Future<void> prepareLocationCheck(int locationId) async {
    if (locationId == 0) {
      throw Exception("Chưa có locationId");
    }

    _isCheckingLocation = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      _classLocation = await _fetchClassLocation(locationId, token);
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
          ? "Đúng vị trí (${distance.toStringAsFixed(1)}m)"
          : "Sai vị trí (${distance.toStringAsFixed(1)}m)";

    } catch (e) {
      _locationStatusMessage = e.toString();
      rethrow;
    } finally {
      _isCheckingLocation = false;
      notifyListeners();
    }
  }

  Future<bool> checkIn(
      int sessionId,
      int locationId,
      String studentId,
      ) async {

    if (_selectedImage == null) {
      throw Exception("Chưa chụp ảnh");
    }

    if (_isWithinAllowedArea != true) {
      throw Exception("Sai vị trí");
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/attendance/checkin'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['sessionId'] = sessionId.toString();
      request.fields['gpsLat'] = _currentPosition!.latitude.toString();
      request.fields['gpsLng'] = _currentPosition!.longitude.toString();

      request.files.add(await http.MultipartFile.fromPath(
        'faceImage',
        _selectedImage!.path,
      ));

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        final body = await response.stream.bytesToString();
        throw Exception(body);
      }

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
    notifyListeners();
  }
}