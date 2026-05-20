import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/api_constants.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading = true;

  String _studentName = 'Sinh viên';
  String _studentCode = '---';
  String _studentId = '';

  int _registeredCount = 0;
  int _remainingCount = 0;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    _animationController.forward();
    _loadHomeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};

      return jsonDecode(
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(parts[1]),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
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

  String _text(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    final text = value.toString().trim();
    return text.isEmpty || text.toLowerCase() == 'null' ? defaultValue : text;
  }

  String _getClassIdFromRegistration(Map<String, dynamic> item) {
    final nested = item['classroom'] ??
        item['classRoom'] ??
        item['class'] ??
        item['classes'] ??
        item['appClass'] ??
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
          item['class_id'] ??
          item['idClass'],
    );
  }

  String _getStudentIdFromRegistration(Map<String, dynamic> item) {
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

  String _getStatus(Map<String, dynamic> item) {
    return _text(
      item['status'] ??
          item['registrationStatus'] ??
          item['approveStatus'] ??
          item['state'] ??
          item['approvalStatus'],
      'PENDING',
    ).toUpperCase();
  }

  bool _isAccepted(String status) {
    final s = status.toUpperCase();

    return s == 'ACCEPTED' ||
        s == 'APPROVED' ||
        s == 'APPROVE' ||
        s == 'APPROVED_BY_ADMIN' ||
        s == 'ACTIVE' ||
        s == 'JOINED' ||
        s == 'SUCCESS';
  }

  bool _isPending(String status) {
    final s = status.toUpperCase();

    return s == 'PENDING' ||
        s == 'OPENING' ||
        s == 'WAITING' ||
        s == 'REQUESTED';
  }

  Future<void> _loadHomeData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final token = await _getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      final jwt = _decodeJwt(token);

      _studentId = _text(
        jwt['studentId'] ??
            jwt['userId'] ??
            jwt['id'] ??
            jwt['sub'],
      );

      _studentName = _text(
        jwt['fullName'] ??
            jwt['name'] ??
            jwt['username'] ??
            jwt['email'] ??
            jwt['sub'],
        'Sinh viên',
      );

      _studentCode = _text(
        jwt['studentCode'] ??
            jwt['code'] ??
            jwt['mssv'] ??
            jwt['studentId'] ??
            jwt['userId'] ??
            jwt['id'] ??
            jwt['sub'],
        '---',
      );

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      int totalClasses = 0;

      final classRes = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=500'),
        headers: headers,
      );

      if (classRes.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(classRes.bodyBytes));
        totalClasses = _safeList(decoded).length;
      }

      final registrations = <Map<String, dynamic>>[];

      final regUrls = [
        '$_baseUrl/class-registrations/$_studentId/classes?page=0&size=500',
        '$_baseUrl/class-registrations/student/$_studentId?page=0&size=500',
        '$_baseUrl/class-registrations?studentId=$_studentId&page=0&size=500',
        '$_baseUrl/class-registrations?page=0&size=500',
      ];

      for (final url in regUrls) {
        try {
          final res = await http.get(
            Uri.parse(url),
            headers: headers,
          );

          debugPrint('HOME REG URL -> $url');
          debugPrint('HOME REG STATUS -> ${res.statusCode}');
          debugPrint('HOME REG BODY -> ${utf8.decode(res.bodyBytes)}');

          if (res.statusCode != 200) continue;

          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          final list = _safeList(decoded);

          for (final raw in list) {
            if (raw is! Map) continue;

            final item = Map<String, dynamic>.from(raw);
            final itemStudentId = _getStudentIdFromRegistration(item);

            if (itemStudentId.isNotEmpty &&
                itemStudentId != '0' &&
                itemStudentId != _studentId) {
              continue;
            }

            final classId = _getClassIdFromRegistration(item);

            if (classId.isEmpty || classId == '0') {
              registrations.add(item);
            } else {
              final existed = registrations.any(
                    (e) => _getClassIdFromRegistration(e) == classId,
              );

              if (!existed) {
                registrations.add(item);
              }
            }
          }

          if (registrations.isNotEmpty) break;
        } catch (e) {
          debugPrint('HOME REG ERROR -> $e');
        }
      }

      int accepted = 0;
      int pending = 0;

      for (final item in registrations) {
        final status = _getStatus(item);

        if (_isAccepted(status)) {
          accepted++;
        } else if (_isPending(status)) {
          pending++;
        }
      }

      if (mounted) {
        setState(() {
          _registeredCount = accepted;
          _pendingCount = pending;

          final remain = totalClasses - accepted - pending;
          _remainingCount = remain < 0 ? 0 : remain;
        });
      }
    } catch (e) {
      debugPrint('HOME LOAD ERROR -> $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.studentHome),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHomeData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                    (route) => false,
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _loadHomeData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildWelcomeHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildQuickStats(),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chức năng chính',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureCard(
                        context,
                        'Đăng ký lớp học',
                        'Xem tất cả lớp và đăng ký lớp mới',
                        Icons.search,
                        AppRoutes.classList,
                        const Color(0xFF2196F3),
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureCard(
                        context,
                        'Lớp của tôi',
                        'Xem lớp đã đăng ký và vào điểm danh',
                        Icons.collections_bookmark,
                        AppRoutes.registeredClasses,
                        const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: const Icon(
              Icons.person,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chào mừng bạn trở lại!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MSSV: $_studentCode',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _buildStatBox(
          'Lớp đã đăng ký',
          _registeredCount.toString(),
          Colors.blue,
        ),
        const SizedBox(width: 12),
        _buildStatBox(
          'Lớp còn lại',
          _remainingCount.toString(),
          Colors.orange,
        ),
        const SizedBox(width: 12),
        _buildStatBox(
          'Chờ xác nhận',
          _pendingCount.toString(),
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatBox(
      String label,
      String value,
      Color color,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context,
      String title,
      String subtitle,
      IconData icon,
      String route,
      Color color,
      ) {
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, route);
        _loadHomeData();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: color.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}