import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/RoomModel.dart';

class SetLocationViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Danh sách các phòng học thật kéo từ Spring Boot
  List<RoomModel> _realLocations = [];
  List<RoomModel> get realLocations => _realLocations;

  // HÀM LẤY DANH SÁCH PHÒNG HỌC (Location) TỪ BACKEND
  Future<void> fetchLocations() async {
    _isLoading = true;
    notifyListeners(); // Báo UI hiện vòng xoay

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      // Gọi API GET /locations của Spring Boot
      final response = await http.get(
        Uri.parse('$_baseUrl/locations?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // Quét mảng dữ liệu và tạo đối tượng RoomModel chứa GPS
        _realLocations = (data['content'] as List).map((item) {
          return RoomModel(
            id: item['locationId']?.toString() ?? item['id']?.toString() ?? '0',
            name: (item['locationCode'] ?? 'Phòng') + ' - ' + (item['address'] ?? ''),
            // Đọc Vĩ độ, Kinh độ và Bán kính từ JSON
            latitude: (item['latitude'] as num?)?.toDouble() ?? 21.028511, // Mặc định ở HN nếu null
            longitude: (item['longitude'] as num?)?.toDouble() ?? 105.804817,
            defaultRadius: (item['radiusMeters'] as num?)?.toDouble() ?? 50.0,
          );
        }).toList();
      }
    } catch (e) {
      print("❌ LỖI LẤY DANH SÁCH PHÒNG HỌC: $e");
    } finally {
      _isLoading = false;
      notifyListeners(); // Tắt vòng xoay
    }
  }
}