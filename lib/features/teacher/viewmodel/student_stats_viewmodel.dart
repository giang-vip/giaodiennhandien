import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/student_state_model.dart';



class StudentStatsViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<StudentStatModel> _statsList = [];
  List<StudentStatModel> get statsList => _statsList;

  int get totalStudents => _statsList.length;
  String get avgAttendance {
    if (_statsList.isEmpty) return "0%";
    double totalPerc = _statsList.fold(0, (sum, item) => sum + item.percent);
    return "${(totalPerc / _statsList.length).toStringAsFixed(0)}%";
  }

  // =========================================================================
  // 1. GỌI API LẤY DANH SÁCH & TÍNH TOÁN
  // =========================================================================
  Future<void> fetchClassStats(String classId) async {
    _isLoading = true;
    _statsList = []; // Xóa data cũ
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      // ⚠️ ĐƯỜNG LINK ĐANG GỌI TẠM THỜI (BẠN CHÚ Ý THEO DÕI LOG XEM CÓ BỊ 404 KHÔNG NHÉ)
      final url = Uri.parse('$_baseUrl/attendance/class/$classId');

      print("\n================= 🚀 BẮT ĐẦU GỌI API THỐNG KÊ LỚP =================");
      print("👉 GỌI LINK: $url");

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });

      print("👉 HTTP STATUS: ${response.statusCode}");
      print("👉 DỮ LIỆU TỪ JAVA TRẢ VỀ:\n${response.body}");
      print("=====================================================================\n");

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> content = data is List ? data : (data['content'] ?? data['data'] ?? []);

        Map<String, StudentStatModel> mapStats = {};

        for (var item in content) {
          // 🔥 ĐÃ FIX: Chỉ đường cho Flutter chui vào trong object 'user' để lấy id và fullName
          String uid = item['user']?['id']?.toString() ?? item['userId']?.toString() ?? '0';

          // Ưu tiên lấy fullName, nếu fullName bị null thì lấy username
          String name = item['user']?['fullName'] ?? item['user']?['username'] ?? item['userName'] ?? 'Sinh viên ẩn danh';

          String status = item['recordStatus']?.toString() ?? item['status']?.toString() ?? 'UNKNOWN';

          if (!mapStats.containsKey(uid)) {
            mapStats[uid] = StudentStatModel(studentName: name, studentId: uid);
          }

          if (status == 'PRESENT' || status == '1') {
            mapStats[uid]!.present++;
          } else {
            mapStats[uid]!.absent++;
          }
        }

        _statsList = mapStats.values.toList();
        _statsList.sort((a, b) => a.studentName.compareTo(b.studentName));
      } else if (response.statusCode == 404) {
        print("❌ LỖI 404: ĐƯỜNG LINK NÀY KHÔNG TỒN TẠI HOẶC TRỐNG DỮ LIỆU!");
        _statsList = [];
      } else {
        print("❌ LỖI KHÁC: Backend trả về mã ${response.statusCode}");
      }
    } catch (e) {
      print("❌ LỖI CODE FLUTTER: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // 2. HÀM TẢI FILE EXCEL
  // =========================================================================
  Future<void> downloadExcel(String classId) async {
    try {
      // ⚠️ Đường link API tải Excel (Cần check lại Backend có viết API này chưa)
      final url = Uri.parse('$_baseUrl/attendance/export/class/$classId');

      print("\n👉 ĐANG GỌI LINK TẢI EXCEL: $url");

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print("❌ Không thể mở trình duyệt để tải file!");
      }
    } catch (e) {
      print("❌ Lỗi khi tải Excel: $e");
    }
  }
}