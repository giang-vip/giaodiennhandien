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
  int _latestLocationId = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<AttendanceViewModel>();
      vm.clearData();

      await _prepareLatestLocation();
    });
  }

  int _resolveSessionId() {
    return int.tryParse(widget.classData?['sessionId']?.toString() ?? '0') ?? 0;
  }

  String _resolveClassId() {
    return (widget.classData?['classId'] ??
        widget.classData?['id'] ??
        widget.classData?['classroomId'] ??
        '')
        .toString();
  }

  int _resolveFallbackLocationId() {
    int locationId =
        int.tryParse(widget.classData?['locationId']?.toString() ?? '0') ?? 0;

    if (locationId == 0 && widget.classData?['locationIds'] != null) {
      final listLocs = widget.classData?['locationIds'];
      if (listLocs is List && listLocs.isNotEmpty) {
        locationId = int.tryParse(listLocs.first.toString()) ?? 0;
      }
    }

    return locationId;
  }

  Future<void> _prepareLatestLocation() async {
    final vm = context.read<AttendanceViewModel>();

    try {
      final latestLocationId = await vm.prepareLocationCheck(
        sessionId: _resolveSessionId(),
        classId: _resolveClassId(),
        fallbackLocationId: _resolveFallbackLocationId(),
      );

      _latestLocationId = latestLocationId;

      if (_latestLocationId == 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Buổi học này chưa được cấu hình vị trí điểm danh!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AttendanceViewModel>();
    final className = widget.classData?['name'] ?? widget.classData?['className'] ?? 'Lớp học';
    final bool canProceed = viewModel.isWithinAllowedArea == true;

    return Scaffold(
      appBar: AppBar(title: Text('Check In: $className')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              "1. XÁC NHẬN VỊ TRÍ",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (viewModel.isCheckingLocation)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          viewModel.isWithinAllowedArea == true
                              ? Icons.check_circle
                              : viewModel.isWithinAllowedArea == false
                              ? Icons.error
                              : Icons.location_searching,
                          color: viewModel.isWithinAllowedArea == true
                              ? Colors.green
                              : viewModel.isWithinAllowedArea == false
                              ? Colors.red
                              : Colors.orange,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            viewModel.locationStatusMessage,
                            style: TextStyle(
                              color: viewModel.isWithinAllowedArea == true
                                  ? Colors.green[700]
                                  : viewModel.isWithinAllowedArea == false
                                  ? Colors.red[700]
                                  : Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (viewModel.currentPosition != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'GPS hiện tại:\n'
                              'Lat: ${viewModel.currentPosition!.latitude.toStringAsFixed(6)}\n'
                              'Lng: ${viewModel.currentPosition!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    if (viewModel.distanceToClass != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Khoảng cách tới phòng admin đang đặt: ${viewModel.distanceToClass!.toStringAsFixed(1)} m'
                              '${viewModel.allowedRadius != null ? ' / Bán kính cho phép: ${viewModel.allowedRadius!.toStringAsFixed(1)} m' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: viewModel.isLoading || viewModel.isCheckingLocation
                          ? null
                          : () async {
                        await _prepareLatestLocation();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                viewModel.isWithinAllowedArea == true
                                    ? 'Bạn đang ở đúng vị trí phòng admin đang đặt.'
                                    : 'Bạn chưa ở đúng vị trí phòng admin đang đặt.',
                              ),
                              backgroundColor:
                              viewModel.isWithinAllowedArea == true
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text("Kiểm tra lại vị trí"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "2. XÁC THỰC KHUÔN MẶT",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.5),
                  width: 4,
                ),
                color: Colors.grey[200],
                image: viewModel.selectedImage != null
                    ? DecorationImage(
                  image: FileImage(viewModel.selectedImage!),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: viewModel.selectedImage == null
                  ? const Icon(Icons.face, size: 80, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: (!canProceed || viewModel.isLoading)
                  ? null
                  : () => context.read<AttendanceViewModel>().pickImageFromCamera(),
              icon: const Icon(Icons.camera_alt),
              label: Text(
                canProceed
                    ? "Mở Camera Chụp Ảnh"
                    : "Cần đúng vị trí mới được chụp ảnh",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canProceed ? Colors.orange : Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: (!canProceed ||
                  viewModel.currentPosition == null ||
                  viewModel.selectedImage == null ||
                  viewModel.isLoading ||
                  viewModel.isCheckingLocation)
                  ? null
                  : () async {
                try {
                  final int realSessionId = _resolveSessionId();

                  if (realSessionId == 0) {
                    throw Exception("Không xác định được phiên điểm danh!");
                  }

                  final latestLocationId = await context
                      .read<AttendanceViewModel>()
                      .prepareLocationCheck(
                    sessionId: realSessionId,
                    classId: _resolveClassId(),
                    fallbackLocationId: _latestLocationId == 0
                        ? _resolveFallbackLocationId()
                        : _latestLocationId,
                  );

                  _latestLocationId = latestLocationId;

                  if (context.read<AttendanceViewModel>().isWithinAllowedArea != true) {
                    throw Exception("Sai vị trí phòng admin đang đặt!");
                  }

                  final prefs = await SharedPreferences.getInstance();
                  final String token = prefs.getString('access_token') ?? '';
                  String currentStudentId = "UNKNOWN";

                  if (token.isNotEmpty) {
                    try {
                      final String payload = token.split('.')[1];
                      final String decodedStr = utf8.decode(
                        base64Url.decode(base64Url.normalize(payload)),
                      );
                      final Map<String, dynamic> decodedMap =
                      jsonDecode(decodedStr);
                      currentStudentId =
                          (decodedMap['studentId'] ??
                              decodedMap['userId'] ??
                              decodedMap['id'] ??
                              decodedMap['sub'])
                              .toString();
                    } catch (_) {}
                  }

                  if (currentStudentId == "UNKNOWN" ||
                      currentStudentId == "0") {
                    throw Exception(
                      "Không lấy được mã Sinh viên. Vui lòng đăng nhập lại!",
                    );
                  }

                  final success = await context
                      .read<AttendanceViewModel>()
                      .checkIn(
                    sessionId: realSessionId,
                    classId: _resolveClassId(),
                    fallbackLocationId: _latestLocationId,
                    studentId: currentStudentId,
                  );

                  if (success && context.mounted) {
                    _showSuccessDialog(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showFailureDialog(
                      context,
                      e.toString().replaceAll("Exception: ", ""),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: viewModel.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                "XÁC NHẬN ĐIỂM DANH",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                Navigator.pop(ctx);
                Navigator.pop(context);
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
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Thử lại'),
            ),
          )
        ],
      ),
    );
  }
}