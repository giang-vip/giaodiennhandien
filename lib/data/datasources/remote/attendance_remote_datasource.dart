import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../models/app_models.dart';

class AttendanceRemoteDataSource {
  final http.Client client;

  AttendanceRemoteDataSource({required this.client});

  Future<List<AppClassModel>> getAttendanceClasses() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      //  LẤY ACCESS TOKEN CHUẨN
      final accessToken = prefs.getString('access_token');

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception("Chưa đăng nhập");
      }

      print("ACCESS TOKEN GỬI LÊN: $accessToken");

      final response = await client.get(
        Uri.parse('${ApiConstants.baseUrl}/classes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print("STATUS CODE: ${response.statusCode}");
      print("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);

        List<dynamic> list;

        if (decodedData is List) {
          list = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('data')) {
          list = decodedData['data'];
        } else {
          print("Sai format JSON");
          return [];
        }

        return list.map((e) => AppClassModel.fromJson(e)).toList();
      }

      // 🔥 QUAN TRỌNG: phân biệt lỗi rõ ràng
      else if (response.statusCode == 401) {
        throw Exception("401 - Token sai hoặc hết hạn");
      } else {
        throw Exception("Server lỗi: ${response.statusCode}");
      }
    } catch (e) {
      print("ERROR: $e");
      rethrow;
    }
  }
}