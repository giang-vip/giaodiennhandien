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

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    className = args?['className']?.toString() ?? "Lớp học";
    classId = args?['classId']?.toString() ?? "0";

    debugPrint("ATTENDANCE HISTORY ARGS -> className=$className, classId=$classId");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AttendanceHistoryViewModel>().fetchHistory(classId);
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await context.read<AttendanceHistoryViewModel>().fetchHistory(classId);
  }

  bool _isPresent(String status) {
    final s = status.trim().toUpperCase();
    return s == 'PRESENT' ||
        s == 'CHECKED_IN' ||
        s == 'ATTENDED' ||
        s == 'SUCCESS' ||
        s == '1' ||
        s == 'TRUE';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AttendanceHistoryViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Lịch sử: $className'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: viewModel.isLoading ? null : _refresh,
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildOverallStats(viewModel),

            if (viewModel.errorMessage.isNotEmpty)
              _buildErrorBox(viewModel.errorMessage),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Chi tiết các buổi học - $className",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            if (viewModel.history.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        viewModel.errorMessage.isNotEmpty
                            ? Icons.lock_outline
                            : Icons.event_busy_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        viewModel.errorMessage.isNotEmpty
                            ? "Không tải được lịch sử điểm danh.\nBạn hãy đăng xuất rồi đăng nhập lại."
                            : "Lớp này chưa có dữ liệu điểm danh.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...viewModel.history.map((record) {
                final bool isPresent = _isPresent(record.status);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Card(
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
                          color: isPresent ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(
                        'Ngày: ${record.date}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text('Giờ điểm danh: ${record.time}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPresent ? Colors.green : Colors.red,
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
                  ),
                );
              }).toList(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
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
          Text(
            className,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: viewModel.percentage / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.white24,
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
                viewModel.totalSessions.toString(),
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
