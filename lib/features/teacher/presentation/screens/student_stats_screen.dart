import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/student_stats_viewmodel.dart';

class StudentStatsScreen extends StatefulWidget {
  final String className;
  final String classId;

  const StudentStatsScreen({
    super.key,
    required this.className,
    required this.classId,
  });

  @override
  State<StudentStatsScreen> createState() => _StudentStatsScreenState();
}

class _StudentStatsScreenState extends State<StudentStatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StudentStatsViewModel>().fetchClassStats(widget.classId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await context.read<StudentStatsViewModel>().fetchClassStats(widget.classId);
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StudentStatsViewModel>();
    final keyword = _normalize(_keyword);

    final filtered = vm.statsList.where((s) {
      return _normalize(s.studentName).contains(keyword) ||
          _normalize(s.studentId).contains(keyword);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Thống kê lớp: ${widget.className}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: vm.isLoading ? null : _reload,
          ),
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.green),
            tooltip: 'Xuất Excel',
            onPressed: vm.isLoading
                ? null
                : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang mở link tải Excel...')),
              );
              vm.downloadExcel(widget.classId);
            },
          ),
        ],
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(vm),
            const SizedBox(height: 14),
            _buildSearchBox(),
            const SizedBox(height: 14),
            if (vm.statsList.isEmpty)
              _buildEmptyState(
                'Lớp này chưa có dữ liệu điểm danh.',
                Icons.analytics_outlined,
                Colors.grey,
              )
            else if (filtered.isEmpty)
              _buildEmptyState(
                'Không tìm thấy sinh viên phù hợp.',
                Icons.search_off,
                Colors.grey,
              )
            else
              ...filtered.map((s) {
                final absent = s.totalSessions - s.present;
                final double percent = s.percentOfClass().clamp(0.0, 100.0);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primary.withOpacity(0.10),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.studentName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mã SV: ${s.studentId}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tổng buổi: ${s.totalSessions} | Có mặt: ${s.present} | Vắng: $absent',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: percent / 100,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey.shade200,
                                  color: _percentColor(percent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${percent.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: _percentColor(percent),
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Đi học',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(StudentStatsViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryWidget(
              label: 'Tổng sinh viên',
              value: vm.totalStudents.toString(),
            ),
          ),
          Container(width: 1, height: 44, color: Colors.grey.shade200),
          Expanded(
            child: _SummaryWidget(
              label: 'Tỷ lệ đi học TB',
              value: vm.avgAttendance,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _keyword = value),
      decoration: InputDecoration(
        hintText: 'Tìm kiếm sinh viên theo tên hoặc mã SV...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _keyword.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _searchController.clear();
            setState(() => _keyword = '');
          },
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 58, color: color.withOpacity(0.75)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _percentColor(double percent) {
    if (percent >= 80) return Colors.green;
    if (percent >= 50) return Colors.orange;
    return Colors.red;
  }
}

class _SummaryWidget extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryWidget({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}