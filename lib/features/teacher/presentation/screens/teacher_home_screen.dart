import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../viewmodel/teacher_home_viewmodel.dart';
import 'manage_class_users_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String _baseUrl = ApiConstants.baseUrl;

  int _teachingStudents = 0;
  bool _isLoadingStudents = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _reloadDashboard();
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ??
        prefs.getString('token') ??
        prefs.getString('jwt') ??
        prefs.getString('accessToken');
  }

  List<dynamic> _safeList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data['content'] is List) return data['content'];
      if (data['data'] is List) return data['data'];
      if (data['result'] is List) return data['result'];
      if (data['items'] is List) return data['items'];

      if (data['data'] is Map && data['data']['content'] is List) {
        return data['data']['content'];
      }

      if (data['result'] is Map && data['result']['content'] is List) {
        return data['result']['content'];
      }
    }

    return [];
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String _getStudentId(Map<String, dynamic> item) {
    final nested = item['student'] ?? item['user'] ?? item['account'];

    if (nested is Map) {
      final id = _text(
        nested['id'] ??
            nested['studentId'] ??
            nested['userId'] ??
            nested['accountId'],
      );

      if (id.isNotEmpty && id != '0') return id;
    }

    return _text(
      item['studentId'] ??
          item['userId'] ??
          item['accountId'] ??
          item['student_id'],
    );
  }

  String _getClassIdFromReg(Map<String, dynamic> item) {
    final nested = item['classroom'] ??
        item['classRoom'] ??
        item['class'] ??
        item['clazz'];

    if (nested is Map) {
      final id = _text(
        nested['id'] ??
            nested['classId'] ??
            nested['classroomId'] ??
            nested['classRoomId'],
      );

      if (id.isNotEmpty && id != '0') return id;
    }

    return _text(
      item['classId'] ??
          item['classroomId'] ??
          item['classRoomId'] ??
          item['class_id'],
    );
  }

  bool _isAccepted(String status) {
    final s = status.toUpperCase();

    return s == 'ACCEPTED' ||
        s == 'APPROVED' ||
        s == 'APPROVE' ||
        s == 'APPROVED_BY_ADMIN' ||
        s == 'ACTIVE' ||
        s == 'JOINED';
  }

  Future<void> _reloadDashboard() async {
    final vm = context.read<TeacherHomeViewModel>();

    await vm.fetchDashboardData();
    await _loadTeachingStudents(vm);
  }

  Future<void> _loadTeachingStudents(TeacherHomeViewModel vm) async {
    try {
      setState(() => _isLoadingStudents = true);

      final token = await _getToken();
      if (token == null || token.isEmpty) return;

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      final classIds = vm.teacherClasses
          .map((e) => _text(e['id'] ?? e['classId'] ?? e['classroomId']))
          .where((e) => e.isNotEmpty && e != '0')
          .toSet();

      final studentIds = <String>{};

      for (final classId in classIds) {
        final urls = [
          '$_baseUrl/class-registrations/$classId/students/status?page=0&size=500&status=ACCEPTED',
          '$_baseUrl/class-registrations/$classId/students/status?page=0&size=500&status=APPROVED',
          '$_baseUrl/class-registrations/class/$classId?page=0&size=500',
          '$_baseUrl/class-registrations?page=0&size=500',
        ];

        for (final url in urls) {
          try {
            final res = await http.get(Uri.parse(url), headers: headers);

            debugPrint('TEACHER HOME STUDENTS URL -> $url');
            debugPrint('TEACHER HOME STUDENTS STATUS -> ${res.statusCode}');
            debugPrint('TEACHER HOME STUDENTS BODY -> ${utf8.decode(res.bodyBytes)}');

            if (res.statusCode != 200) continue;

            final decoded = jsonDecode(utf8.decode(res.bodyBytes));
            final list = _safeList(decoded);

            for (final raw in list) {
              if (raw is! Map) continue;

              final item = Map<String, dynamic>.from(raw);
              final regClassId = _getClassIdFromReg(item);

              if (regClassId.isNotEmpty && regClassId != classId) continue;

              final status = _text(
                item['status'] ??
                    item['registrationStatus'] ??
                    item['approveStatus'] ??
                    item['state'],
              );

              if (!_isAccepted(status)) continue;

              final studentId = _getStudentId(item);
              if (studentId.isNotEmpty && studentId != '0') {
                studentIds.add(studentId);
              }
            }

            if (studentIds.isNotEmpty) break;
          } catch (e) {
            debugPrint('TEACHER HOME LOAD STUDENTS ERROR -> $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _teachingStudents = studentIds.length;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi hệ thống không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TeacherHomeViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Dashboard Giáo viên',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: viewModel.isLoading ? null : _reloadDashboard,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _reloadDashboard,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildWelcomeHeader(viewModel),
              const SizedBox(height: 24),
              _buildStatsSection(viewModel),
              const SizedBox(height: 24),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              _buildRecentClasses(viewModel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(TeacherHomeViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, ${viewModel.teacherName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quản lý lớp học, điểm danh và sinh viên',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(TeacherHomeViewModel viewModel) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: viewModel.totalClasses.toString(),
            subtitle: 'lớp học',
            icon: Icons.class_rounded,
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            value: viewModel.openClasses.toString(),
            subtitle: 'đang điểm danh',
            icon: Icons.how_to_reg_rounded,
            color: const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            value: _isLoadingStudents ? '...' : _teachingStudents.toString(),
            subtitle: 'SV đang dạy',
            icon: Icons.people_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chức năng nhanh',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.15,
          children: [
            _buildFeatureCard(
              title: 'Tạo lớp mới',
              subtitle: 'Khởi tạo lớp học',
              icon: Icons.add_circle_outline_rounded,
              color: const Color(0xFF2563EB),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.createClass).then((_) {
                  if (context.mounted) _reloadDashboard();
                });
              },
            ),
            _buildFeatureCard(
              title: 'Quản lý lớp',
              subtitle: 'Xem và chỉnh lớp',
              icon: Icons.class_outlined,
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.manageClasses).then((_) {
                  if (context.mounted) _reloadDashboard();
                });
              },
            ),
            _buildFeatureCard(
              title: 'Quản lý sinh viên',
              subtitle: 'Theo từng lớp học',
              icon: Icons.groups_2_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageClassUsersScreen(),
                  ),
                ).then((_) {
                  if (context.mounted) _reloadDashboard();
                });
              },
            ),
            _buildFeatureCard(
              title: 'Thống kê',
              subtitle: 'Báo cáo điểm danh',
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF10B981),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.attendanceStats).then((_) {
                  if (context.mounted) _reloadDashboard();
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentClasses(TeacherHomeViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lớp học của bạn',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (viewModel.teacherClasses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Hiện chưa có lớp nào',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          )
        else
          ...viewModel.teacherClasses.take(5).map(
                (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Icon(
                    item['isOpen'] == true
                        ? Icons.radio_button_checked_rounded
                        : Icons.menu_book_rounded,
                    color: item['isOpen'] == true
                        ? const Color(0xFF16A34A)
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['title'] ?? 'Chưa có tên lớp',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    item['isOpen'] == true ? 'Đang mở' : 'Chưa mở',
                    style: TextStyle(
                      color: item['isOpen'] == true
                          ? const Color(0xFF16A34A)
                          : Colors.grey[700],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}