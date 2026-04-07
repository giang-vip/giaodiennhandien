import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/attendance_history_viewmodel.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  String className = "Lớp học";
  String classId = "0";
  bool _loadedArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_loadedArgs) return;
    _loadedArgs = true;

    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    className = args?['className']?.toString() ?? "Lớp học";
    classId = args?['classId']?.toString() ?? "0";

    print("ATTENDANCE HISTORY ARGS -> className=$className, classId=$classId");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceHistoryViewModel>().fetchHistory(classId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AttendanceHistoryViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text('Lịch sử: $className')),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildOverallStats(viewModel),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Chi tiết các buổi học",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: viewModel.history.isEmpty
                ? const Center(
              child: Text("Chưa có dữ liệu điểm danh nào."),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              itemCount: viewModel.history.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = viewModel.history[index];
                final bool isPresent =
                    record.status.toUpperCase() == 'PRESENT';

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPresent
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      child: Icon(
                        isPresent ? Icons.check : Icons.close,
                        color:
                        isPresent ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      'Ngày: ${record.date}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle:
                    Text('Giờ điểm danh: ${record.time}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                        isPresent ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPresent ? 'CÓ MẶT' : 'VẮNG MẶT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildOverallStats(AttendanceHistoryViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: viewModel.percentage / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${viewModel.percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Tỷ lệ đi học',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                'Có mặt',
                viewModel.totalPresent.toString(),
                Icons.check_circle_outline,
              ),
              _buildStatItem(
                'Vắng/Trễ',
                viewModel.totalAbsent.toString(),
                Icons.error_outline,
              ),
              _buildStatItem(
                'Tổng buổi',
                viewModel.history.length.toString(),
                Icons.event_note,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}