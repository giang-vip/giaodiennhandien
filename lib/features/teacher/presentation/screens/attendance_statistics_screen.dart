import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_routes.dart';
import '../../viewmodel/teacher_viewmodel.dart';

// ĐÃ ĐỔI THÀNH STATEFUL WIDGET
class AttendanceStatisticsScreen extends StatefulWidget {
  const AttendanceStatisticsScreen({super.key});

  @override
  State<AttendanceStatisticsScreen> createState() => _AttendanceStatisticsScreenState();
}

class _AttendanceStatisticsScreenState extends State<AttendanceStatisticsScreen> {

  @override
  void initState() {
    super.initState();
    // BÍ QUYẾT LÀ ĐÂY: Tự động gọi API lấy 5 lớp về ngay khi mở màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherViewModel>().fetchClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TeacherViewModel>();
    final classes = viewModel.realClasses;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Class for Statistics')),
      // Thêm vòng xoay loading cho đẹp trong lúc đợi tải 5 lớp
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
          ? const Center(child: Text('No classes found.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: classes.length,
        itemBuilder: (context, index) {
          final item = classes[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(child: Icon(Icons.class_)),
              title: Text(item.className, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Time: ${item.startTime} - ${item.endTime}'),
              trailing: const Icon(Icons.analytics_outlined, color: Colors.blue),
              onTap: () {
                // Chuyển sang màn Thống kê kèm ID Lớp
                Navigator.pushNamed(
                  context,
                  AppRoutes.studentStats,
                  arguments: {
                    'className': item.className,
                    'classId': item.id,
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}