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

  void _showTopNotification(
      BuildContext context,
      String message,
      Color bgColor,
      IconData icon,
      ) {
    ScaffoldMessenger.of(context).showSnackBar(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 160,
          left: 16,
          right: 16,
        ),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => viewModel.fetchRegisteredClasses(),
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
          ? const Center(
        child: Text("Bạn chưa đăng ký lớp học nào hoặc chưa được duyệt."),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: classes.length,
        itemBuilder: (context, index) {
          final item = classes[index];
          final bool isActive = viewModel.isClassActive(item.id);
          final String remainingTime =
          viewModel.getRemainingTime(item.id);
          final String status =
          viewModel.getRegistrationStatus(item.id);

          final bool isAccepted = status == 'ACCEPTED';
          final bool isPending = status == 'PENDING';

          Color statusBg;
          Color statusTextColor;
          IconData statusIcon;
          String statusText;

          if (isAccepted) {
            statusBg = Colors.green.withOpacity(0.10);
            statusTextColor = Colors.green;
            statusIcon = Icons.verified_rounded;
            statusText = 'Đã được chấp nhận vào lớp';
          } else if (isPending) {
            statusBg = Colors.orange.withOpacity(0.12);
            statusTextColor = Colors.orange;
            statusIcon = Icons.hourglass_top_rounded;
            statusText =
            'Đăng ký đang chờ giảng viên / quản trị viên duyệt';
          } else {
            statusBg = Colors.grey.withOpacity(0.10);
            statusTextColor = Colors.grey.shade700;
            statusIcon = Icons.info_outline_rounded;
            statusText = 'Trạng thái không xác định';
          }

          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusTextColor.withOpacity(0.30),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(statusIcon, color: statusTextColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAccepted && isActive) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              remainingTime.isNotEmpty
                                  ? 'Phiên điểm danh đang mở • Còn lại $remainingTime'
                                  : 'Phiên điểm danh đang mở',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isAccepted
                          ? () {
                        if (isActive) {
                          final sessionId =
                          viewModel.getActiveSessionId(item.id);
                          final locationId =
                              viewModel.getSessionLocationId(
                                item.id,
                              ) ??
                                  0;

                          Navigator.pushNamed(
                            context,
                            AppRoutes.attendance,
                            arguments: {
                              'name': item.className,
                              'id': item.id,
                              'sessionId': sessionId,
                              'locationId': locationId,
                            },
                          ).then((_) {
                            context
                                .read<RegisteredClassesViewModel>()
                                .fetchRegisteredClasses();
                          });
                        } else {
                          _showTopNotification(
                            context,
                            'Giáo viên chưa mở phiên điểm danh!',
                            Colors.orange,
                            Icons.warning_amber_rounded,
                          );
                        }
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAccepted && isActive
                            ? Colors.green
                            : isAccepted
                            ? Colors.white
                            : Colors.grey.shade300,
                        foregroundColor: isAccepted && isActive
                            ? Colors.white
                            : isAccepted
                            ? Colors.grey.shade600
                            : Colors.grey.shade700,
                        side: isAccepted && !isActive
                            ? BorderSide(
                          color: Colors.grey.shade400,
                          width: 1.5,
                        )
                            : BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        isAccepted
                            ? (isActive
                            ? (remainingTime.isNotEmpty
                            ? 'VÀO ĐIỂM DANH • $remainingTime'
                            : 'VÀO ĐIỂM DANH')
                            : 'CHƯA MỞ ĐIỂM DANH')
                            : 'CHỜ DUYỆT',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isAccepted
                          ? () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.attendanceHistory,
                          arguments: {
                            'classId': item.id,
                            'className': item.className,
                          },
                        );
                      }
                          : null,
                      icon: const Icon(Icons.history),
                      label: const Text(
                        'XEM LỊCH SỬ ĐIỂM DANH',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isAccepted
                            ? AppColors.primary
                            : Colors.grey,
                        side: BorderSide(
                          color: isAccepted
                              ? AppColors.primary
                              : Colors.grey.shade400,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
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