import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/RoomModel.dart';

class SetLocationViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isGettingCurrentLocation = false;
  bool get isGettingCurrentLocation => _isGettingCurrentLocation;

  List<RoomModel> _realLocations = [];
  List<RoomModel> get realLocations => _realLocations;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  String? _locationError;
  String? get locationError => _locationError;

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

  Future<void> fetchLocations() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.get(
        Uri.parse('$_baseUrl/locations?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("LOCATION STATUS: ${response.statusCode}");
      print("LOCATION BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List content = _safeList(data);

        _realLocations = content.map((item) {
          return RoomModel(
            id: item['locationId']?.toString() ??
                item['id']?.toString() ??
                '0',
            name:
            '${item['locationCode'] ?? 'Phòng'} - ${item['address'] ?? ''}',
            latitude:
            (item['latitude'] as num?)?.toDouble() ?? 21.028511,
            longitude:
            (item['longitude'] as num?)?.toDouble() ?? 105.804817,
            defaultRadius:
            (item['radiusMeters'] as num?)?.toDouble() ?? 50.0,
          );
        }).toList();
      } else if (response.statusCode == 401) {
        throw Exception("Token không hợp lệ hoặc đã hết hạn");
      } else {
        throw Exception("Không lấy được danh sách phòng học");
      }
    } catch (e) {
      print("LỖI LẤY DANH SÁCH PHÒNG HỌC: $e");
      _realLocations = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> getCurrentLocation() async {
    _isGettingCurrentLocation = true;
    _locationError = null;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationError = "Thiết bị chưa bật dịch vụ vị trí";
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _locationError = "Bạn đã từ chối quyền truy cập vị trí";
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        _locationError =
        "Quyền vị trí bị từ chối vĩnh viễn. Hãy bật lại trong cài đặt máy";
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentPosition = position;

      print(
        "CURRENT LOCATION: lat=${position.latitude}, lng=${position.longitude}",
      );

      return true;
    } catch (e) {
      _locationError = "Không lấy được vị trí hiện tại: $e";
      print("LỖI LẤY VỊ TRÍ HIỆN TẠI: $e");
      return false;
    } finally {
      _isGettingCurrentLocation = false;
      notifyListeners();
    }
  }

  Future<void> loadInitialData() async {
    await Future.wait([
      fetchLocations(),
      getCurrentLocation(),
    ]);
  }
}