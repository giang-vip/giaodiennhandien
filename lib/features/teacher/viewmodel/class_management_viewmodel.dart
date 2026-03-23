import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/app_models.dart';
import '../../../core/constants/api_constants.dart';

class ClassManagementViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AppClassModel> _realClasses = [];
  List<AppClassModel> get realClasses => _realClasses;

  final Map<String, Map<String, dynamic>> _activeSessionData = {};

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final payload = token.split('.')[1];
      return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))));
    } catch(e) { return {}; }
  }

  Future<void> fetchClasses() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? ''; // Bắt lỗi nếu không có token

      if (token.isEmpty) {
        print("❌ [LỖI NGHIÊM TRỌNG] Không tìm thấy JWT Token trong máy điện thoại!");
      }

      final jwtData = _decodeJwt(token);
      final String myTeacherId = jwtData['sub']?.toString() ?? '';

      final url = Uri.parse('$_baseUrl/sessions?page=0&size=50');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      };

      // =========================================================
      // 🔥 MÁY QUÉT DEBUG: NỘI SOI REQUEST VÀ RESPONSE 🔥
      // =========================================================
      print("\n================= 🚀 BẮT ĐẦU GỌI API SESSIONS =================");
      print("📤 [GỬI ĐI] URL: $url");
      print("📤 [GỬI ĐI] METHOD: GET");
      // Chỉ in 20 ký tự đầu của Token để kiểm tra xem có gửi đúng chuẩn Bearer không
      final tokenPreview = token.length > 20 ? "${token.substring(0, 20)}..." : token;
      print("📤 [GỬI ĐI] HEADER Authorization: Bearer $tokenPreview");

      final sessionResponse = await http.get(url, headers: headers);

      print("📥 [NHẬN VỀ] MÃ TRẠNG THÁI: ${sessionResponse.statusCode}");
      print("📥 [NHẬN VỀ] BODY (NỘI DUNG LỖI TỪ BACKEND):");
      print(sessionResponse.body);
      print("=================================================================\n");
      // =========================================================

      Map<String, dynamic> openSessions = {};
      if (sessionResponse.statusCode == 200) {
        final sessionData = jsonDecode(utf8.decode(sessionResponse.bodyBytes));
        final List<dynamic> sessionContent = sessionData is List ? sessionData : (sessionData['content'] ?? sessionData['data'] ?? []);

        for (var session in sessionContent) {
          final status = session['status']?.toString().toUpperCase();
          if (status == 'OPEN' || status == '1') {
            final sClassId = session['classroomId']?.toString() ??
                session['classRoomId']?.toString() ??
                session['classId']?.toString() ??
                session['classRoomId']?.toString() ??
                session['classRoom']?['id']?.toString() ??
                session['classRoom']?['classId']?.toString();

            if (sClassId != null && sClassId != 'null') {
              openSessions[sClassId] = session;
              _activeSessionData[sClassId] = {
                "sessionId": session['sessionId'] ?? session['id'],
                "classId": int.parse(sClassId),
                "status": "OPEN",
                "locationId": session['locationId'] ?? session['location']?['locationId'] ?? session['location']?['id'] ?? 0,
                "startTime": session['startTime'],
                "endTime": session['endTime']
              };
            }
          }
        }
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=50'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> classContent = data is List ? data : (data['content'] ?? data['data'] ?? []);

        _realClasses = classContent.where((item) => item['teacherId']?.toString() == myTeacherId).map((item) {
          final classId = item['id']?.toString() ?? item['classId']?.toString() ?? '0';

          final bool isOpenInDB = openSessions.containsKey(classId);

          final savedRoomId = prefs.getString('class_${classId}_room');
          final savedRadius = prefs.getDouble('class_${classId}_radius');

          return AppClassModel(
            id: classId,
            teacherId: item['teacherId']?.toString() ?? '0',
            className: item['title'] ?? 'Chưa có tên',
            description: item['description'] ?? '',
            teacherName: 'Giảng viên',
            startTime: item['startDate'] ?? 'N/A',
            endTime: item['endDate'] ?? 'N/A',
            isAttendanceOpen: isOpenInDB,
            roomId: savedRoomId,
            radius: savedRadius,
          );
        }).toList();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =================================================================================
  // 2. MỞ ĐIỂM DANH (POST SESSION)
  // =================================================================================

    Future<void> toggleAttendance(String classId, int minutes) async {
      int index = _realClasses.indexWhere((c) => c.id == classId);
      if (index == -1) return;

      final currentClass = _realClasses[index];

      // NẾU ĐANG TẮT -> BẬT LÊN
      if (!currentClass.isAttendanceOpen) {
        if (currentClass.roomId == null) throw Exception("Vui lòng ấn 'Set Location' để chọn phòng học trước!");
        try {
          _isLoading = true;
          notifyListeners();
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token');
          final startTime = DateTime.now();
          final endTime = startTime.add(Duration(minutes: minutes));

          // CHÚ Ý: Gửi chuẩn JSON cho API Create Session
          final requestBody = {
            "title": "Điểm danh lớp ${currentClass.className}",
            "startTime": startTime.toIso8601String(),//.split('.')[0]
            "endTime": endTime.toIso8601String(),
            "locationId": int.tryParse(currentClass.roomId!) ?? 0,
            "classId": int.parse(classId),
            "status": "OPEN"
          };

          print(
              "\n================= 🚀 [API POST] MỞ ĐIỂM DANH =================");
          print("📤 [GỬI ĐI] PAYLOAD: ${jsonEncode(requestBody)}");

          final response = await http.post(
            Uri.parse('$_baseUrl/sessions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token'
            },
            body: jsonEncode(requestBody),
          );

          print("📥 [NHẬN VỀ] STATUS: ${response.statusCode}");
          print("📥 [NHẬN VỀ] BODY: ${response.body}");
          print("================================================================\n");

          if (response.statusCode == 200 || response.statusCode == 201) {
            final responseData = jsonDecode(utf8.decode(response.bodyBytes));
            requestBody['sessionId'] =
                responseData['sessionId'] ?? responseData['id'] ??
                    responseData['data']?['sessionId'] ?? 0;
            _activeSessionData[classId] = requestBody;

            _realClasses[index] = currentClass.copyWith(
                isAttendanceOpen: true, attendanceDuration: minutes);
            notifyListeners();

            Timer(
                Duration(minutes: minutes), () => _closeAttendanceAPI(classId));
          } else {
            throw Exception("Backend từ chối MỞ điểm danh: ${response
                .statusCode} - ${response.body}");
          }
        } finally {
          _isLoading = false;
          notifyListeners();
        }
      }
      // NẾU ĐANG BẬT -> TẮT ĐI
      else {
        await _closeAttendanceAPI(classId);
      }
    }

  // ====================================================================================
  // 🔥 ĐÃ SỬA LỖI: Bắt buộc gọi API PUT thành công mới được gạt công tắc về FALSE 🔥
  // ====================================================================================
  Future<void> _closeAttendanceAPI(String classId) async {
    int index = _realClasses.indexWhere((c) => c.id == classId);
    if (index == -1 || !_realClasses[index].isAttendanceOpen) return;

    final sessionData = _activeSessionData[classId];
    if (sessionData == null) return;

    try {
      _isLoading = true;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      // Đổi trạng thái thành CLOSED để gửi lên Backend
      sessionData['status'] = "CLOSED";
      final sessionId = sessionData['sessionId'];

      print("📤 [DEBUG PUT] Đang gửi yêu cầu ĐÓNG phiên điểm danh ID: $sessionId");

      final response = await http.put(
        Uri.parse('$_baseUrl/sessions/$sessionId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(sessionData),
      );

      // Nếu Backend trả về lỗi (không phải 200), lập tức ném lỗi ra màn hình cho người dùng thấy
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Backend từ chối ĐÓNG điểm danh (Lỗi ${response.statusCode}): ${response.body}");
      }

      // CHỈ KHI BACKEND BÁO THÀNH CÔNG, TA MỚI XÓA DỮ LIỆU VÀ TẮT CÔNG TẮC GIAO DIỆN
      _activeSessionData.remove(classId);
      _realClasses[index] = _realClasses[index].copyWith(isAttendanceOpen: false);

    } catch (e) {
      print("❌ [LỖI API PUT] $e");
      rethrow; // Ném lỗi văng ra màn hình ClassManagementScreen để hiển thị thanh thông báo đỏ
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void deleteClass(String classId) {}

  void updateClass(AppClassModel updatedClass) async {
    int index = _realClasses.indexWhere((c) => c.id == updatedClass.id);
    if (index != -1) {
      _realClasses[index] = updatedClass;
      notifyListeners();

      // =================================================================
      // ĐÃ SỬA LỖI TRẮNG TAY: Lưu cứng vị trí vào bộ nhớ đệm của điện thoại
      // =================================================================
      final prefs = await SharedPreferences.getInstance();
      if (updatedClass.roomId != null) {
        await prefs.setString('class_${updatedClass.id}_room', updatedClass.roomId!);
      }
      if (updatedClass.radius != null) {
        await prefs.setDouble('class_${updatedClass.id}_radius', updatedClass.radius!);
      }
    }
  }
}
