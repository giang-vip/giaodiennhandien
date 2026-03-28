import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../models/app_models.dart';

class AttendanceRemoteDataSource {
  final http.Client client;

  AttendanceRemoteDataSource({required this.client});

  Future<List<AppClassModel>> getAttendanceClasses() async {
    try {
      // 1. Gọi API lấy danh sách lớp
      final response = await client.get(
        Uri.parse('${ApiConstants.baseUrl}/classes'), // Đảm bảo URL này đúng trong BE
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': 'Bearer <token>', // Thêm nếu BE yêu cầu login
        },
      );

      if (response.statusCode == 200) {
        // 2. Giải mã JSON
        final dynamic decodedData = json.decode(response.body);

        // 3. Xử lý lỗi "Map vs List" ở đây
        List<dynamic> list;

        if (decodedData is List) {
          // Trường hợp BE trả về thẳng: [{}, {}]
          list = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('data')) {
          // Trường hợp BE trả về bọc: {"data": [{}, {}]}
          list = decodedData['data'];
        } else {
          // Nếu BE trả về Map mà không có key 'data' (như lỗi bạn gặp)
          print("Dữ liệu BE trả về không đúng định dạng List: $decodedData");
          return [];
        }

        // 4. Chuyển đổi từ List JSON sang List Object Flutter
        return list.map((item) => AppClassModel.fromJson(item)).toList();
      } else {
        throw Exception('Lỗi Server: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ LỖI TẠI DATASOURCE: $e");
      rethrow;
    }
  }
}