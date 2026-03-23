import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/attendance_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceScreen extends StatefulWidget {
  final Map<String, dynamic>? classData;
  const AttendanceScreen({super.key, this.classData});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    // Xóa dữ liệu cũ (ảnh cũ, tọa độ cũ) khi vừa vào màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceViewModel>().clearData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AttendanceViewModel>();
    final className = widget.classData?['name'] ?? 'Lớp học';

    return Scaffold(
      appBar: AppBar(title: Text('Check In: $className')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // ==========================================
            // 1. PHẦN KIỂM TRA GPS
            // ==========================================
            const Text("1. XÁC NHẬN VỊ TRÍ", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          viewModel.currentPosition != null ? Icons.check_circle : Icons.location_off,
                          color: viewModel.currentPosition != null ? Colors.green : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            viewModel.currentPosition != null
                                ? "Đã lấy được vị trí GPS\nLat: ${viewModel.currentPosition!.latitude.toStringAsFixed(4)}\nLng: ${viewModel.currentPosition!.longitude.toStringAsFixed(4)}"
                                : "Chưa có dữ liệu vị trí",
                            style: TextStyle(
                                color: viewModel.currentPosition != null ? Colors.green[700] : Colors.grey,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await context.read<AttendanceViewModel>().fetchCurrentLocation();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Lấy GPS thành công!'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                          }
                        }
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text("Lấy vị trí hiện tại"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ==========================================
            // 2. PHẦN KIỂM TRA KHUÔN MẶT (CAMERA)
            // ==========================================
            const Text("2. XÁC THỰC KHUÔN MẶT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 16),

            // Khung hiển thị ảnh
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 4),
                color: Colors.grey[200],
                image: viewModel.selectedImage != null
                    ? DecorationImage(image: FileImage(viewModel.selectedImage!), fit: BoxFit.cover)
                    : null,
              ),
              child: viewModel.selectedImage == null
                  ? const Icon(Icons.face, size: 80, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.read<AttendanceViewModel>().pickImageFromCamera(),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Mở Camera Chụp Ảnh"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            ),
            const SizedBox(height: 48),

            // ==========================================
            // 3. NÚT GỬI API ĐIỂM DANH
            // ==========================================
            ElevatedButton(
              onPressed: (viewModel.currentPosition == null || viewModel.selectedImage == null || viewModel.isLoading)
                  ? null
                  : () async {
                try {
                  // === IN DỮ LIỆU RA ĐỂ KIỂM TRA ===
                  print("====== DỮ LIỆU LỚP HỌC ======");
                  print(widget.classData);
                  print("=============================");

                  // Dùng int.tryParse để ÉP KIỂU an toàn, chống lỗi do JSON trả về String hay Double
                  final int realSessionId = int.tryParse(widget.classData?['sessionId']?.toString() ?? '0') ?? 0;

                  // Đọc locationId một cách an toàn
                  int locationId = int.tryParse(widget.classData?['locationId']?.toString() ?? '0') ?? 0;

                  // Nếu Backend trả về "locationIds" (dạng mảng) theo như ClassRoomResponseDto
                  if (locationId == 0 && widget.classData?['locationIds'] != null) {
                    var listLocs = widget.classData?['locationIds'] as List;
                    if (listLocs.isNotEmpty) {
                      locationId = int.tryParse(listLocs[0].toString()) ?? 0;
                    }
                  }

                  // TẠM THỜI BỎ QUA NẾU VẪN LỖI ĐỂ TEST AI (Bạn có thể bỏ comment dòng dưới để test)
                  // if (locationId == 0) locationId = 1; // Ép cứng luôn lấy phòng ID = 1 ở DB của bạn

                  if (locationId == 0) {
                    throw Exception("Buổi học này chưa được cấu hình phòng học!");
                  }

                  // Lấy mã Sinh viên
                  // ĐOẠN NÀY ĐỂ LẤY ID LÀ "8" TỪ TOKEN RA
                  final prefs = await SharedPreferences.getInstance();
                  final String token = prefs.getString('jwt_token') ?? '';
                  String currentStudentId = "UNKNOWN";

                  if (token.isNotEmpty) {
                    try {
                      final String payload = token.split('.')[1];
                      final String decodedStr = utf8.decode(base64Url.decode(base64Url.normalize(payload)));
                      final Map<String, dynamic> decodedMap = jsonDecode(decodedStr);

                      currentStudentId = decodedMap['sub'].toString(); // Sẽ lấy ra được số "8"
                    } catch (e) {
                      print("Lỗi giải mã token: $e");
                    }
                  }

                  if (currentStudentId == "UNKNOWN" || currentStudentId == "0") {
                    throw Exception("Không lấy được mã Sinh viên. Vui lòng đăng nhập lại!");
                  }
                  // GỌI VIEWMODEL
                  final success = await context.read<AttendanceViewModel>().checkIn(
                    realSessionId,
                    locationId,
                    currentStudentId,
                  );

                  if (success && context.mounted) {
                    _showSuccessDialog(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showFailureDialog(context, e.toString());
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: viewModel.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("XÁC NHẬN ĐIỂM DANH", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 80),
        content: const Text(
          'Điểm danh thành công!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Tắt Dialog
                Navigator.pop(context); // Quay về trang Lớp của tôi
              },
              child: const Text('ĐÓNG'),
            ),
          ),
        ],
      ),
    );
  }

  void _showFailureDialog(BuildContext context, String errorMsg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.error_outline, color: Colors.red, size: 70),
        content: Text(
          'Điểm danh thất bại:\n$errorMsg',
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Thử lại')),
          )
        ],
      ),
    );
  }
}