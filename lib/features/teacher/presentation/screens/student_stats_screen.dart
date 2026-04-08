import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/student_stats_viewmodel.dart';

class StudentStatsScreen extends StatefulWidget {
  final String className;
  final String classId; // Nhận thêm classId

  const StudentStatsScreen({super.key, required this.className, required this.classId});

  @override
  State<StudentStatsScreen> createState() => _StudentStatsScreenState();
}

class _StudentStatsScreenState extends State<StudentStatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentStatsViewModel>().fetchClassStats(widget.classId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StudentStatsViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Thống kê: ${widget.className}', style: const TextStyle(fontSize: 18)),
        actions: [
          // NÚT TẢI EXCEL Ở GÓC PHẢI
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.green, size: 28),
            tooltip: 'Xuất báo cáo Excel',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang mở link tải Excel...')),
              );
              viewModel.downloadExcel(widget.classId);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryWidget(label: 'Tổng sinh viên', value: viewModel.totalStudents.toString()),
                _SummaryWidget(label: 'Tỷ lệ đi học', value: viewModel.avgAttendance),
              ],
            ),
          ),
          Expanded(
            child: viewModel.statsList.isEmpty
                ? const Center(child: Text("Lớp này chưa có dữ liệu điểm danh."))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: viewModel.statsList.length,
              itemBuilder: (context, index) {
                final s = viewModel.statsList[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
                    title: Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Mã SV: ${s.studentId}\nCó mặt: ${s.present} | Vắng: ${s.absent}'),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${s.percent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: s.percent >= 80 ? Colors.green : (s.percent >= 50 ? Colors.orange : Colors.red),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Text('Tỷ lệ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryWidget extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryWidget({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
      ],
    );
  }
}