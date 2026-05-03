import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/class_management_viewmodel.dart';

class AttendanceStatisticsScreen extends StatefulWidget {
  const AttendanceStatisticsScreen({super.key});

  @override
  State<AttendanceStatisticsScreen> createState() =>
      _AttendanceStatisticsScreenState();
}

class _AttendanceStatisticsScreenState extends State<AttendanceStatisticsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClassManagementViewModel>().fetchClasses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reloadClasses() async {
    await context.read<ClassManagementViewModel>().fetchClasses();
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _openStudentStats({
    required String classId,
    required String className,
  }) {
    final id = classId.trim();
    final name = className.trim().isEmpty ? 'Lớp học' : className.trim();

    if (id.isEmpty || id == '0' || id.toLowerCase() == 'null') {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Không xác định được mã lớp.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.studentStats,
      arguments: {
        'classId': id,
        'className': name,
        'id': id,
        'name': name,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClassManagementViewModel>();
    final classes = viewModel.realClasses;

    final key = _normalize(_keyword);
    final filteredClasses = key.isEmpty
        ? classes
        : classes.where((item) {
      return _normalize(item.className).contains(key) ||
          _normalize(item.id).contains(key);
    }).toList();

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
            tooltip: 'Tải lại',
            onPressed: viewModel.isLoading ? null : _reloadClasses,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _reloadClasses,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _keyword = value);
              },
              decoration: InputDecoration(
                hintText: 'Tìm kiếm lớp theo tên hoặc mã lớp...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
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
            ),
            const SizedBox(height: 16),
            if (classes.isEmpty)
              _buildEmptyState(
                icon: Icons.class_outlined,
                title: 'Không tìm thấy lớp nào.',
                subtitle: 'Hãy tạo lớp hoặc kiểm tra tài khoản giáo viên.',
              )
            else if (filteredClasses.isEmpty)
              _buildEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Không tìm thấy lớp phù hợp.',
                subtitle: 'Thử nhập tên lớp hoặc mã lớp khác.',
              )
            else
              ...filteredClasses.map((item) {
                final classId = item.id.trim();
                final isInvalidId = classId.isEmpty ||
                    classId == '0' ||
                    classId.toLowerCase() == 'null';

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
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      _openStudentStats(
                        classId: classId,
                        className: item.className,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
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
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.className.trim().isEmpty
                                      ? 'Chưa có tên lớp'
                                      : item.className,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Mã lớp: ${isInvalidId ? 'Không hợp lệ' : classId}',
                                  style: TextStyle(
                                    color: isInvalidId
                                        ? Colors.redAccent
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.isAttendanceOpen
                                      ? 'Trạng thái: Đang mở điểm danh'
                                      : 'Trạng thái: Đã đóng',
                                  style: TextStyle(
                                    color: item.isAttendanceOpen
                                        ? Colors.green
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 80),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(icon, size: 62, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}