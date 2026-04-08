import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/attendance_record_model.dart';



class AttendanceHistoryViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AttendanceRecordModel> _history = [];
  List<AttendanceRecordModel> get history => _history;

  // Tính toán thống kê (Bắt cả trường hợp status là 'PRESENT' hoặc '1')
  int get totalPresent => _history.where((r) => r.status.toUpperCase() == 'PRESENT' || r.status == '1').length;
  int get totalAbsent => _history.where((r) => r.status.toUpperCase() != 'PRESENT' && r.status != '1').length;
  double get percentage => _history.isEmpty ? 0 : (totalPresent / _history.length) * 100;

  int _getMyStudentId(String token) {
    try {
      final payload = token.split('.')[1];
      final decoded = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))));
      return int.parse(decoded['sub'].toString());
    } catch (e) {
      return 0;
    }
  }

  Future<void> fetchHistory(String classId) async {
    _isLoading = true;
    _history = [];
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final myStudentId = _getMyStudentId(token);

      //  THỬ GỌI API THEO CHUẨN (Bạn check log xem nếu 404 thì báo mình chỉnh lại link)
      final url = Uri.parse('$_baseUrl/attendance/user/$myStudentId');

      print("\n=================  BẮT ĐẦU GỌI API LỊCH SỬ =================");
      print(" GỌI LINK: $url");

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });

      print("HTTP STATUS: ${response.statusCode}");
      print("DỮ LIỆU TỪ JAVA TRẢ VỀ:\n${response.body}");
      print("==============================================================\n");

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> content = data is List ? data : (data['content'] ?? data['data'] ?? []);

        // Dùng Map để lọc trùng lặp. Key là sessionId.
        Map<String, AttendanceRecordModel> uniqueRecords = {};

        for (var item in content) {
          // 1. SỬA KEY NGÀY GIỜ (Khớp với checkinTime của Java)
          String rawDate = item['checkinTime'] ?? item['createAt'] ?? item['date'] ?? '';
          String displayDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : 'N/A';
          String displayTime = rawDate.length >= 16 ? rawDate.substring(11, 16) : 'N/A';

          // 2. SỬA KEY SESSION ID (Khớp với attendanceSessionId của Java)
          String sessionId = item['attendanceSessionId']?.toString() ??
              item['sessionId']?.toString() ??
              item['recordId']?.toString() ??
              displayDate;

          // 3. SỬA KEY TRẠNG THÁI (Khớp với recordStatus của Java)
          String status = item['recordStatus']?.toString() ?? item['status']?.toString() ?? 'UNKNOWN';

          // 4. LƯU Ý VỀ CLASS ID:
          // Vì API /user/{id} này của Java KHÔNG trả về classId, nên chúng ta
          // phải tạm thời bỏ qua bước lọc (if recordClassId == classId).
          // Nhét luôn dữ liệu vào Map. Nếu bạn điểm danh 2 lần trong cùng 1 Session (như session 38),
          // Map sẽ tự động ghi đè và chỉ tính là 1 lần Có mặt cho buổi hôm đó!

          uniqueRecords[sessionId] = AttendanceRecordModel(
            date: displayDate,
            time: displayTime,
            status: status,
            sessionId: sessionId,
          );
        }

        _history = uniqueRecords.values.toList();

        // Sắp xếp ngày mới nhất lên đầu danh sách
        _history.sort((a, b) => b.date.compareTo(a.date));
      }
    } catch (e) {
      print("LỖI CODE LẤY LỊCH SỬ: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}