import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/class_list_viewmodel.dart';

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({super.key});

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassListViewModel>().fetchAvailableClasses();
    });
  }

  void _showTopNotification(
      String message,
      Color bgColor,
      IconData icon,
      ) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 160,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClassListViewModel>();
    final classes = viewModel.availableClasses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký lớp học'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ClassListViewModel>().fetchAvailableClasses();
            },
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
          ? const Center(
        child: Text(
          "Không có lớp học nào để đăng ký.\nHoặc bạn đã đăng ký hết các lớp!",
          textAlign: TextAlign.center,
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: classes.length,
        itemBuilder: (context, index) {
          final item = classes[index];
          final isFull = viewModel.isClassFull(item.id);
          final capacityText = viewModel.getCapacityText(item.id);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.className,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.person,
                    'Giảng viên: ${item.teacherName}',
                  ),
                  _buildInfoRow(
                    Icons.access_time,
                    'Thời gian: ${item.startTime} - ${item.endTime}',
                  ),
                  _buildInfoRow(
                    Icons.description,
                    'Mô tả: ${item.description}',
                  ),
                  _buildInfoRow(
                    Icons.groups_2_outlined,
                    capacityText,
                  ),
                  const SizedBox(height: 10),
                  if (isFull)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.25),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.block_rounded,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lớp đã đủ 75 sinh viên, không thể đăng ký thêm.',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: viewModel.isLoading || isFull
                          ? null
                          : () async {
                        final success = await context
                            .read<ClassListViewModel>()
                            .registerClass(item.id);

                        if (!mounted) return;

                        if (success) {
                          _showTopNotification(
                            viewModel.lastActionMessage,
                            Colors.green,
                            Icons.check_circle,
                          );

                          await Future.delayed(
                            const Duration(milliseconds: 1200),
                          );

                          if (!mounted) return;

                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.registeredClasses,
                          );
                        } else {
                          _showTopNotification(
                            viewModel.lastActionMessage.isNotEmpty
                                ? viewModel.lastActionMessage
                                : 'Lỗi đăng ký lớp! Vui lòng thử lại.',
                            Colors.red,
                            Icons.error_outline,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFull
                            ? Colors.grey.shade400
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isFull ? 'LỚP ĐÃ ĐẦY' : 'ĐĂNG KÝ NGAY',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
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
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}