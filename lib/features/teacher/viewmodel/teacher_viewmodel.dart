import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/RoomModel.dart';
import '../../../data/models/app_models.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';

class TeacherViewModel extends ChangeNotifier {
  // LƯU Ý: Đổi IP này thành IP Wifi máy tính của bạn ipconfig
  // final String _baseUrl = 'http://192.168.1.21:8081/api';
  // ĐÃ SỬA: Lấy đường dẫn trực tiếp từ file cấu hình chung
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Dữ liệu thật từ DB
  List<AppClassModel> _realClasses = [];
  List<AppClassModel> get realClasses => _realClasses;

  List<RoomModel> _realLocations = [];
  List<RoomModel> get realLocations => _realLocations;

  // Lưu thông tin các session đang mở để lúc sau có data gọi API Đóng (CLOSED)
  final Map<String, Map<String, dynamic>> _activeSessionData = {};

  // Hàm giải mã JWT Token để lấy ID người dùng
  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = parts[1];
      var normalized = base64Url.normalize(payload);
      var resp = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(resp);
    } catch(e) {
      return {};
    }
  }

  // LẤY DANH SÁCH PHÒNG HỌC
  Future<void> fetchLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.get(
        Uri.parse('$_baseUrl/locations?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _realLocations = (data['content'] as List).map((item) => RoomModel(
          id: item['id']?.toString() ?? item['locationId']?.toString() ?? '0',
          name: item['locationCode'] + ' - ' + (item['address'] ?? ''),
        )).toList();
        notifyListeners();
      }
    } catch (e) {
      print("LỖI LẤY PHÒNG HỌC: $e");
    }
  }

  // LẤY DANH SÁCH LỚP HỌC
  Future<void> fetchClasses() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      // Lấy ID của giáo viên từ Token
      final jwtData = _decodeJwt(token!);
      final String myTeacherId = jwtData['sub']?.toString() ?? '';

      final response = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // CHỈ LẤY LỚP CỦA GIÁO VIÊN NÀY
        _realClasses = (data['content'] as List)
            .where((item) => item['teacherId']?.toString() == myTeacherId)
            .map((item) => AppClassModel(
          id: item['id']?.toString() ?? item['classId']?.toString() ?? '0',
          teacherId: item['teacherId']?.toString() ?? '0',
          className: item['title'] ?? 'Chưa có tên',
          description: item['description'] ?? '',
          teacherName: 'Giảng viên',
          startTime: item['startDate'] ?? 'N/A',
          endTime: item['endDate'] ?? 'N/A',
          isAttendanceOpen: false,
        )).toList();
      }
    } catch (e) {
      print("LỖI LẤY LỚP HỌC: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // TẠO LỚP MỚI
  Future<bool> createClassAPI({
    required String title,
    required String description,
    required int teacherId,
    required List<int> locationIds}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      // Lấy ID của chính mình để tạo lớp
      final jwtData = _decodeJwt(token!);
      final int myTeacherId = int.parse(jwtData['sub']!.toString());

      final response = await http.post(
        Uri.parse('$_baseUrl/classrooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          "teacherId": myTeacherId,
          "title": title,
          "description": description,
          "startDate": DateTime.now().toIso8601String().split('T')[0],
          "endDate": DateTime.now().add(const Duration(days: 90)).toIso8601String().split('T')[0],
          "locationIds": locationIds
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchClasses();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // BẬT TẮT ĐIỂM DANH KHI GẠT NÚT
  Future<void> toggleAttendance(String classId, int minutes) async {
    int index = _realClasses.indexWhere((c) => c.id == classId);
    if (index == -1) return;

    final currentClass = _realClasses[index];
    final bool isTurningOn = !_realClasses[index].isAttendanceOpen;

    if (isTurningOn) {
      // 1. BẮT BUỘC PHẢI CÓ LOCATION TỪ LỚP HỌC
      if (currentClass.roomId == null) {
        throw Exception("Vui lòng ấn 'Set Location' để chọn phòng học cho lớp này trước khi mở điểm danh!");
      }

      try {
        _isLoading = true;
        notifyListeners();

        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');

        // 2. NGHIỆP VỤ THỜI GIAN THEO YÊU CẦU CỦA BẠN:
        final startTime = DateTime.now(); // Lấy thời gian hiện tại làm bắt đầu
        final endTime = startTime.add(Duration(minutes: minutes)); // Cộng thêm số phút để ra kết thúc


        // Chuẩn bị dữ liệu gửi lên (Lưu lại để sau này gửi lệnh ĐÓNG)
        final requestBody = {
          "title": "Điểm danh lớp ${currentClass.className}",
          "startTime": startTime.toIso8601String(),
          "endTime": endTime.toIso8601String(),
          "locationId": int.parse(currentClass.roomId!), // DÙNG ID PHÒNG THẬT CỦA LỚP
          "classId": int.parse(classId),
          "status": "OPEN" // TRẠNG THÁI BẮT ĐẦU LÀ MỞ
        };

        // 3. GỌI API
        final response = await http.post(
          Uri.parse('$_baseUrl/sessions'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(utf8.decode(response.bodyBytes));
          final int sessionId = responseData['sessionId'] ?? responseData['data']?['sessionId'] ?? 0;

          print("✅ MỞ ĐIỂM DANH THÀNH CÔNG (Session ID: $sessionId)");

          // Lưu lại dữ liệu để xíu nữa Update đóng
          requestBody['sessionId'] = sessionId;
          _activeSessionData[classId] = requestBody;

          // Cập nhật UI
          _realClasses[index] = currentClass.copyWith(isAttendanceOpen: true, attendanceDuration: minutes);
          notifyListeners();

          // 4. HẸN GIỜ TỰ ĐỘNG GỌI API ĐÓNG SAU KHI HẾT PHÚT
          Timer(Duration(minutes: minutes), () {
            _closeAttendanceAPI(classId);
          });
        } else {
          throw Exception("Lỗi API Backend: ${response.body}");
        }
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      // 5. NẾU GIÁO VIÊN TỰ GẠT TẮT SỚM -> GỌI API ĐÓNG LUÔN
      await _closeAttendanceAPI(classId);
    }
  }

  // =======================================================
  // HÀM NGẦM ĐỂ GỌI API UPDATE (PUT) STATUS THÀNH CLOSED
  // =======================================================
  Future<void> _closeAttendanceAPI(String classId) async {
    int index = _realClasses.indexWhere((c) => c.id == classId);
    if (index == -1 || !_realClasses[index].isAttendanceOpen) return;

    final sessionData = _activeSessionData[classId];
    if (sessionData == null) return; // Không có data thì thôi

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      // Đổi trạng thái thành CLOSED
      sessionData['status'] = "CLOSED";
      final sessionId = sessionData['sessionId'];

      // GỌI API UPDATE (PUT)
      final response = await http.put(
        Uri.parse('$_baseUrl/sessions/$sessionId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(sessionData), // Gửi lại toàn bộ data cũ nhưng status là CLOSED
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ ĐÓNG ĐIỂM DANH THÀNH CÔNG TẠI BACKEND (Session ID: $sessionId)");
      } else {
        print("❌ LỖI API ĐÓNG: ${response.body}");
      }
    } catch (e) {
      print("❌ LỖI EXCEPTION ĐÓNG: $e");
    } finally {
      // Dọn dẹp bộ nhớ và tắt UI
      _activeSessionData.remove(classId);
      _realClasses[index] = _realClasses[index].copyWith(isAttendanceOpen: false);
      notifyListeners();
    }
  }

  void deleteClass(String classId) {
    print("Xóa lớp chưa được gọi API");
  }

  // Cập nhật thông tin lớp (như gắn phòng, bán kính)
  void updateClass(AppClassModel updatedClass) {
    int index = _realClasses.indexWhere((c) => c.id == updatedClass.id);
    if (index != -1) {
      _realClasses[index] = updatedClass;
      notifyListeners();
      // Tương lai nếu có API cập nhật Location cho Class, bạn sẽ gọi HTTP PUT ở đây
    }
  }
}