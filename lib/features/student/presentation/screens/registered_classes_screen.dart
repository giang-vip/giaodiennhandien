import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/registered_classes_viewmodel.dart';
import 'attendance_history_screen.dart';

class RegisteredClassesScreen extends StatefulWidget {
  const RegisteredClassesScreen({super.key});

  @override
  State<RegisteredClassesScreen> createState() =>
      _RegisteredClassesScreenState();
}

class _RegisteredClassesScreenState extends State<RegisteredClassesScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<RegisteredClassesViewModel>().fetchRegisteredClasses();
      _startCountdownTimer();
    });
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      context
          .read<RegisteredClassesViewModel>()
          .updateCountdownAndCloseExpiredSessions();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _showTopNotification(
      String message,
      Color bgColor,
      IconData icon,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
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
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 160,
            left: 16,
            right: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Color _statusBgColor(String status) {
    final s = status.toUpperCase();

    if (s == 'APPROVED' || s == 'ACCEPTED' || s == 'APPROVE') {
      return Colors.green.withOpacity(.10);
    }

    if (s == 'REJECTED' || s == 'DECLINED') {
      return Colors.red.withOpacity(.10);
    }

    return Colors.orange.withOpacity(.12);
  }

  Color _statusTextColor(String status) {
    final s = status.toUpperCase();

    if (s == 'APPROVED' || s == 'ACCEPTED' || s == 'APPROVE') {
      return Colors.green;
    }

    if (s == 'REJECTED' || s == 'DECLINED') {
      return Colors.red;
    }

    return Colors.orange;
  }

  IconData _statusIcon(String status) {
    final s = status.toUpperCase();

    if (s == 'APPROVED' || s == 'ACCEPTED' || s == 'APPROVE') {
      return Icons.verified;
    }

    if (s == 'REJECTED' || s == 'DECLINED') {
      return Icons.cancel;
    }

    return Icons.hourglass_top;
  }

  void _openAttendanceHistory({
    required String classId,
    required String className,
  }) {
    if (classId.isEmpty || classId == '0') {
      _showTopNotification(
        'Không xác định được lớp cần xem thống kê.',
        Colors.red,
        Icons.error_outline,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceHistoryScreen(
          classId: classId,
          className: className,
        ),
        settings: RouteSettings(
          arguments: {
            'classId': classId,
            'className': className,
            'id': classId,
            'name': className,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RegisteredClassesViewModel>();
    final classes = vm.registeredClasses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lớp của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: vm.isLoading
                ? null
                : () async {
              await context
                  .read<RegisteredClassesViewModel>()
                  .fetchRegisteredClasses();
            },
          ),
        ],
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          await context
              .read<RegisteredClassesViewModel>()
              .fetchRegisteredClasses();
        },
        child: classes.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 220),
            Center(
              child: Text(
                'Bạn chưa có lớp nào.\nHãy đăng ký lớp học trước nhé.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        )
            : ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final item = classes[index];

            final status = vm.getRegistrationStatus(item.id);
            final isApproved = vm.isRegistrationApproved(item.id);
            final isOpen = vm.isClassAttendanceAvailable(item.id);
            final remain = vm.getRemainingText(item);
            final statusText = vm.getRegistrationStatusText(item.id);

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOpen)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'ĐANG MỞ ĐIỂM DANH',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      item.className,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusBgColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _statusIcon(status),
                            color: _statusTextColor(status),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _statusTextColor(status),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? Colors.green.withOpacity(.08)
                            : Colors.grey.withOpacity(.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOpen ? Icons.timer : Icons.timer_off,
                            color: isOpen ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isOpen
                                  ? 'Phiên điểm danh đang mở • $remain'
                                  : 'Phiên điểm danh đã đóng hoặc chưa mở',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                isOpen ? Colors.green : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isOpen
                            ? () {
                          final sessionId =
                          vm.getActiveSessionId(item.id);

                          if (sessionId == null) {
                            _showTopNotification(
                              'Phiên điểm danh đã hết hạn',
                              Colors.red,
                              Icons.timer_off,
                            );
                            return;
                          }

                          Navigator.pushNamed(
                            context,
                            AppRoutes.attendance,
                            arguments: {
                              'id': item.id,
                              'classId': item.id,
                              'name': item.className,
                              'className': item.className,
                              'sessionId': sessionId,
                              'locationId':
                              vm.getSessionLocationId(item.id) ?? 0,
                            },
                          ).then((_) {
                            if (!mounted) return;
                            context
                                .read<RegisteredClassesViewModel>()
                                .fetchRegisteredClasses();
                          });
                        }
                            : () {
                          if (!isApproved) {
                            _showTopNotification(
                              'Lớp này đang chờ duyệt',
                              Colors.orange,
                              Icons.hourglass_top,
                            );
                            return;
                          }

                          _showTopNotification(
                            'Phiên điểm danh đã đóng hoặc giáo viên chưa mở',
                            Colors.orange,
                            Icons.warning_amber,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          isOpen ? Colors.green : Colors.white,
                          foregroundColor:
                          isOpen ? Colors.white : Colors.grey,
                          side: isOpen
                              ? BorderSide.none
                              : const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isOpen
                              ? 'VÀO ĐIỂM DANH • $remain'
                              : isApproved
                              ? 'ĐÃ ĐÓNG / CHƯA MỞ ĐIỂM DANH'
                              : 'ĐANG CHỜ DUYỆT',
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
                        onPressed: isApproved
                            ? () {
                          _openAttendanceHistory(
                            classId: item.id,
                            className: item.className,
                          );
                        }
                            : () {
                          _showTopNotification(
                            'Lớp chưa được admin duyệt nên chưa có thống kê điểm danh',
                            Colors.orange,
                            Icons.lock_outline,
                          );
                        },
                        icon: Icon(
                          isApproved
                              ? Icons.history
                              : Icons.lock_outline,
                        ),
                        label: Text(
                          isApproved
                              ? 'XEM LỊCH SỬ ĐIỂM DANH'
                              : 'CHƯA ĐƯỢC XEM THỐNG KÊ',
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
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
