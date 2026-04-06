import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/registered_classes_viewmodel.dart';

class RegisteredClassesScreen extends StatefulWidget {
  const RegisteredClassesScreen({super.key});

  @override
  State<RegisteredClassesScreen> createState() => _RegisteredClassesScreenState();
}

class _RegisteredClassesScreenState extends State<RegisteredClassesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RegisteredClassesViewModel>().fetchRegisteredClasses();
    });
  }

  void _showTopNotification(BuildContext context, String message, Color bgColor, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 160, left: 16, right: 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RegisteredClassesViewModel>();
    final classes = viewModel.registeredClasses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lớp của tôi'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => viewModel.fetchRegisteredClasses())
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
          ? const Center(child: Text("Bạn chưa đăng ký lớp học nào."))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: classes.length,
        itemBuilder: (context, index) {
          final item = classes[index];

          // Kiểm tra xem Giáo viên đã mở điểm danh chưa
          final bool isActive = viewModel.isClassActive(item.id);
          // Thêm dòng này để kiểm tra log:
          print("Check class ${item.id} - isActive: $isActive - Map: ${viewModel.getActiveSessionId(item.id)}");

          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.className, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.person, 'Giảng viên: ${item.teacherName}'),
                  _buildInfoRow(Icons.access_time, 'Thời gian: ${item.startTime} - ${item.endTime}'),
                  // ĐÃ BỔ SUNG: Hiển thị thêm mô tả lớp
                  _buildInfoRow(Icons.description, 'Mô tả: ${item.description}'),

                  const Divider(height: 24),
                  // 1. NÚT ĐIỂM DANH
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isActive) {
                          // Nếu giáo viên bật nút, lấy ID Session ra và phi sang Camera ngay
                          final sessionId = viewModel.getActiveSessionId(item.id);

                          // 🔥 BỔ SUNG DÒNG NÀY: Lấy locationId từ ViewModel
                          final locationId = viewModel.getSessionLocationId(item.id) ?? 0;

                          Navigator.pushNamed(
                            context,
                            AppRoutes.attendance,
                            arguments: {
                              'name': item.className,
                              'id': item.id,
                              'sessionId': sessionId,
                              'locationId': locationId, // 🔥 BỔ SUNG DÒNG NÀY ĐỂ TRUYỀN SANG MÀN SAU
                            },
                          ).then((_) {
                            // 🔥 QUAN TRỌNG: reload lại data khi quay về
                            context.read<RegisteredClassesViewModel>().fetchRegisteredClasses();
                          }
                          );
                        } else {
                          // Báo lỗi trôi nổi góc trên
                          _showTopNotification(context, 'Giáo viên chưa mở phiên điểm danh!', Colors.orange, Icons.warning_amber_rounded);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        // NẾU MỞ THÌ XANH, NẾU ĐÓNG THÌ NỀN TRẮNG VIỀN XÁM
                        backgroundColor: isActive ? Colors.green : Colors.white,
                        foregroundColor: isActive ? Colors.white : Colors.grey.shade600,
                        side: isActive ? BorderSide.none : BorderSide(color: Colors.grey.shade400, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                          isActive ? 'VÀO ĐIỂM DANH' : 'CHƯA MỞ ĐIỂM DANH',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                    ),
                  ),

                  const SizedBox(height: 12), // Khoảng cách giữa 2 nút

                  // 2. NÚT XEM LỊCH SỬ (THÊM MỚI)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Chuyển sang màn hình lịch sử và truyền ID lớp sang
                        Navigator.pushNamed(
                          context,
                          AppRoutes.attendanceHistory,
                          arguments: {
                            'classId': item.id,
                            'className': item.className,
                          },
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('XEM LỊCH SỬ ĐIỂM DANH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary, // Chữ màu xanh giống theme
                        side: const BorderSide(color: AppColors.primary, width: 1.5), // Viền xanh
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
        ],
      ),
    );
  }
}