import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/teacher_viewmodel.dart';

class AttendanceStatisticsScreen extends StatefulWidget {
  const AttendanceStatisticsScreen({super.key});

  @override
  State<AttendanceStatisticsScreen> createState() =>
      _AttendanceStatisticsScreenState();
}

class _AttendanceStatisticsScreenState extends State<AttendanceStatisticsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherViewModel>().fetchClasses();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TeacherViewModel>();
    final classes = viewModel.realClasses;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Thống kê điểm danh',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Tải lại danh sách lớp',
            onPressed: viewModel.isLoading
                ? null
                : () {
              context.read<TeacherViewModel>().fetchClasses();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
          ? const Center(
        child: Text(
          'Không tìm thấy lớp nào.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          await context.read<TeacherViewModel>().fetchClasses();
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final item = classes[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  item.className,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mã lớp: ${item.id}',
                        style: TextStyle(
                          color: item.id == '0'
                              ? Colors.redAccent
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Thời gian: ${item.startTime} - ${item.endTime}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                onTap: () {
                  final classId = item.id.trim();

                  if (classId.isEmpty || classId == '0') {
                    _showError(
                      'Lỗi mã lớp = 0. Cần sửa TeacherViewModel để lấy đúng id/classId từ backend.',
                    );
                    return;
                  }

                  Navigator.pushNamed(
                    context,
                    AppRoutes.studentStats,
                    arguments: {
                      'className': item.className,
                      'classId': classId,
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
