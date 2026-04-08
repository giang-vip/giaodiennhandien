import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert'; // Bổ sung để mã hóa Base64
import '../../../core/constants/api_constants.dart';
class AttendanceViewModel extends ChangeNotifier {
  final String _baseUrl = ApiConstants.baseUrl;
  // 🛠️ THÊM URL CỦA SERVER PYTHON AI (Đổi IP 192.168.x.x thành IP máy tính của bạn)
  final String _aiBaseUrl = ApiConstants.aiBaseUrl;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Biến lưu trữ Ảnh và Vị trí
  File? _selectedImage;
  File? get selectedImage => _selectedImage;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // 1. LẤY VỊ TRÍ GPS TỪ ĐIỆN THOẠI
  Future<void> fetchCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Kiểm tra xem GPS có bật không
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Vui lòng bật GPS (Vị trí) trên điện thoại.');
    }

    // Kiểm tra quyền truy cập vị trí
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Bạn đã từ chối quyền truy cập vị trí.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Quyền vị trí bị từ chối vĩnh viễn, hãy vào Cài đặt để mở lại.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Lấy tọa độ với độ chính xác cao nhất
      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. MỞ CAMERA TRƯỚC ĐỂ CHỤP ẢNH
  Future<void> pickImageFromCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      // imageQuality: 50, // Giảm chất lượng xuống một chút
      // // maxWidth: 800,    // THÊM DÒNG NÀY: Giới hạn chiều rộng
      // // maxHeight: 800,   // THÊM DÒNG NÀY: Giới hạn chiều cao
    );

    if (pickedFile != null) {
      _selectedImage = File(pickedFile.path);
      notifyListeners();
    }
  }

  // BỔ SUNG: HÀM LẤY TỌA ĐỘ LỚP HỌC TỪ BACKEND BẰNG LOCATION ID
  Future<Map<String, double>> _fetchClassLocation(int locationId, String token) async {
    print(" Đang lấy tọa độ lớp học từ locationId: $locationId...");
    try {
      // 1. Thử gọi với URL có chữ 's' (chuẩn RESTful thường dùng số nhiều)
      var response = await http.get(
        Uri.parse('$_baseUrl/locations/$locationId'), // Thử URL số nhiều
        headers: {'Authorization': 'Bearer $token'},
      );

      // Nếu API trả về 404 (Không tìm thấy), thử gọi lại với URL không có chữ 's'
      if (response.statusCode == 404) {
        response = await http.get(
          Uri.parse('$_baseUrl/location/$locationId'), // Thử URL số ít
          headers: {'Authorization': 'Bearer $token'},
        );
      }
      print(">>> HTTP Status lấy Location: ${response.statusCode}");
      print(">>> Nội dung trả về từ BE: ${response.body}");
      if (response.statusCode == 200) {
        // Tùy theo việc Backend trả về bọc trong "data" hay trả trực tiếp
        var responseData = jsonDecode(utf8.decode(response.bodyBytes));

        // Kiểm tra xem Backend có bọc dữ liệu trong chữ "data" không
        var dataObj = responseData.containsKey('data') ? responseData['data'] : responseData;
        // Trích xuất từ JSON (LocationResponseDto)
        double lat = responseData['latitude'] ?? 0.0;
        double lon = responseData['longitude'] ?? 0.0;
        double radius = responseData['radiusMeters'] ?? 50.0;

        return {"lat": lat, "lon": lon, "radius": radius};
      } else {
        throw Exception("API trả về lỗi ${response.statusCode}. Bạn kiểm tra lại đường dẫn API Location của Java nhé!");
      }
    } catch (e) {
      throw Exception("Lỗi lấy tọa độ lớp: $e");
    }
  }

  // ĐÃ SỬA LẠI: Truyền locationId thay vì classLat, classLon
  Future<bool> checkIn(int sessionId, int locationId, String currentStudentId) async {
    if (_selectedImage == null || _currentPosition == null) {
      throw Exception("Vui lòng chụp ảnh khuôn mặt và Lấy vị trí GPS trước!");
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      // ======================================================================
      // BƯỚC 1: ĐI LẤY TỌA ĐỘ LỚP HỌC DỰA VÀO LOCATION_ID
      // ======================================================================
      Map<String, double> classLoc = await _fetchClassLocation(locationId, token);

      if (classLoc["lat"] == 0.0 || classLoc["lon"] == 0.0) {
        throw Exception("Phòng học này chưa được cài đặt tọa độ!");
      }

      // ======================================================================
      // BƯỚC 2: GỬI DỮ LIỆU SANG PYTHON AI
      // ======================================================================
      print("⏳ BƯỚC 2: Gửi dữ liệu sang AI để kiểm tra...");
      List<int> imageBytes = await _selectedImage!.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      var aiResponse = await http.post(
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
        var aiData = jsonDecode(aiResponse.body);
        if (!aiData['isSuccess']) {
          throw Exception(aiData['message']);
        }
      } else {
        throw Exception("Không thể kết nối AI Server (Lỗi ${aiResponse.statusCode})");
      }

      // ======================================================================
      // BƯỚC 3: GỌI BACKEND JAVA ĐỂ LƯU ĐIỂM DANH
      // ======================================================================
      print("⏳ BƯỚC 3: Gửi kết quả lên Backend...");
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/attendance/checkin'));
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['sessionId'] = sessionId.toString();
      request.fields['gpsLat'] = _currentPosition!.latitude.toString();
      request.fields['gpsLng'] = _currentPosition!.longitude.toString();

      var multipartFile = await http.MultipartFile.fromPath('faceImage', _selectedImage!.path);
      request.files.add(multipartFile);

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

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
    notifyListeners();
  }
}