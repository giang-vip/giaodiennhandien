import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';

class ManageClassUsersScreen extends StatefulWidget {
  const ManageClassUsersScreen({super.key});

  @override
  State<ManageClassUsersScreen> createState() => _ManageClassUsersScreenState();
}

class _ManageClassUsersScreenState extends State<ManageClassUsersScreen>
    with SingleTickerProviderStateMixin {
  final String _baseUrl = ApiConstants.baseUrl;

  late TabController _tabController;

  bool _isLoadingClasses = true;
  bool _isLoadingRegistrations = false;
  bool _isProcessing = false;

  List<Map<String, dynamic>> _myClasses = [];
  List<Map<String, dynamic>> _pendingStudents = [];
  List<Map<String, dynamic>> _acceptedStudents = [];

  Map<String, dynamic>? _selectedClass;
  String? _errorMessage;

  final List<String> _pendingStatuses = [
    'PENDING',
    'OPENING',
    'WAITING',
    'REQUESTED',
  ];

  final List<String> _acceptedStatuses = [
    'ACCEPTED',
    'APPROVED',
    'APPROVE',
    'APPROVED_BY_ADMIN',
    'ACTIVE',
    'JOINED',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMyClasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final payload = token.split('.')[1];
      return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      );
    } catch (_) {
      return {};
    }
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

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

      if (data['data'] is Map && data['data']['items'] is List) {
        return data['data']['items'];
      }
    }

    return [];
  }

  Future<String> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ??
        prefs.getString('token') ??
        prefs.getString('jwt') ??
        prefs.getString('accessToken') ??
        '';
  }

  String _getClassId(Map<String, dynamic> map) {
    return _text(
      map['id'] ??
          map['classId'] ??
          map['classroomId'] ??
          map['classRoomId'],
    );
  }

  String _getTeacherId(Map<String, dynamic> map) {
    return _text(
      map['teacherId'] ??
          map['teacher']?['id'] ??
          map['teacher']?['userId'] ??
          map['user']?['id'] ??
          map['createdBy'],
    );
  }

  String _getRegistrationId(Map<String, dynamic> map) {
    return _text(
      map['registrationId'] ??
          map['id'] ??
          map['classRegistrationId'] ??
          map['registerId'],
    );
  }

  String _getRegistrationClassId(Map<String, dynamic> map) {
    final nested = map['classroom'] ??
        map['classRoom'] ??
        map['class'] ??
        map['classes'] ??
        map['appClass'] ??
        map['clazz'];

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
      map['classId'] ??
          map['classroomId'] ??
          map['classRoomId'] ??
          map['class_id'] ??
          map['idClass'],
    );
  }

  String _getStudentId(Map<String, dynamic> map) {
    final nested = map['student'] ?? map['user'] ?? map['account'];

    if (nested is Map) {
      final id = _text(
        nested['id'] ??
            nested['studentId'] ??
            nested['userId'],
      );

      if (id.isNotEmpty && id != '0') return id;
    }

    return _text(
      map['studentId'] ??
          map['userId'] ??
          map['accountId'] ??
          map['student_id'],
    );
  }

  String _getStudentName(Map<String, dynamic> map) {
    final nested = map['student'] ?? map['user'] ?? map['account'];

    if (nested is Map) {
      final name = _text(
        nested['fullName'] ??
            nested['name'] ??
            nested['username'] ??
            nested['email'],
      );

      if (name.isNotEmpty) return name;
    }

    final name = _text(
      map['studentName'] ??
          map['fullName'] ??
          map['name'] ??
          map['username'] ??
          map['email'],
    );

    return name.isNotEmpty ? name : 'Chưa có tên';
  }

  String _getStatus(Map<String, dynamic> map) {
    final status = _text(
      map['status'] ??
          map['registrationStatus'] ??
          map['approveStatus'] ??
          map['state'] ??
          map['approvalStatus'],
    ).toUpperCase();

    return status.isEmpty ? 'PENDING' : status;
  }

  bool _isPendingStatus(String status) {
    return _pendingStatuses.contains(status.toUpperCase());
  }

  bool _isAcceptedStatus(String status) {
    return _acceptedStatuses.contains(status.toUpperCase());
  }

  void _showMessage(
      String message, {
        Color color = Colors.black87,
        IconData? icon,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white),
                const SizedBox(width: 10),
              ],
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

  Future<void> _fetchMyClasses() async {
    setState(() {
      _isLoadingClasses = true;
      _errorMessage = null;
    });

    try {
      final token = await _readToken();

      if (token.isEmpty) {
        throw Exception('Không tìm thấy access token');
      }

      final jwt = _decodeJwt(token);
      final teacherId = _text(
        jwt['sub'] ?? jwt['userId'] ?? jwt['id'],
      );

      final response = await http.get(
        Uri.parse('$_baseUrl/classrooms?page=0&size=500'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('ADMIN CLASSES STATUS -> ${response.statusCode}');
      debugPrint('ADMIN CLASSES BODY -> ${utf8.decode(response.bodyBytes)}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> content = _safeList(data);

        final myClasses = content.where((item) {
          if (item is! Map) return false;

          final map = Map<String, dynamic>.from(item);
          final itemTeacherId = _getTeacherId(map);

          if (teacherId.isEmpty) return true;
          if (itemTeacherId.isEmpty) return true;

          return itemTeacherId == teacherId;
        }).map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final id = _getClassId(map);

          return {
            'id': id,
            'title': _text(
              map['title'] ?? map['className'] ?? map['name'],
            ).isNotEmpty
                ? _text(map['title'] ?? map['className'] ?? map['name'])
                : 'Lớp học #$id',
            'description': _text(map['description']),
            'startDate': _text(map['startDate'] ?? map['startTime']).isNotEmpty
                ? _text(map['startDate'] ?? map['startTime'])
                : 'N/A',
            'endDate': _text(map['endDate'] ?? map['endTime']).isNotEmpty
                ? _text(map['endDate'] ?? map['endTime'])
                : 'N/A',
          };
        }).where((e) {
          return _text(e['id']).isNotEmpty && _text(e['id']) != '0';
        }).toList();

        setState(() {
          _myClasses = myClasses;
        });
      } else if (response.statusCode == 401) {
        throw Exception('Phiên đăng nhập hết hạn, vui lòng đăng nhập lại');
      } else {
        throw Exception('Không tải được danh sách lớp (${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingClasses = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapRegistrationItem(
      Map<String, dynamic> map,
      String fallbackStatus,
      ) {
    final status = _getStatus(map);
    final registrationId = _getRegistrationId(map);
    final classId = _getRegistrationClassId(map);
    final studentId = _getStudentId(map);

    return {
      'registrationId': registrationId,
      'classId': classId,
      'classTitle': _text(
        map['classTitle'] ??
            map['className'] ??
            map['classroom']?['title'] ??
            map['classroom']?['className'] ??
            map['class']?['title'] ??
            map['class']?['className'],
      ),
      'studentId': studentId,
      'studentName': _getStudentName(map),
      'registeredAt': _text(
        map['registeredAt'] ??
            map['createdAt'] ??
            map['createdDate'],
      ),
      'status': status.isNotEmpty ? status : fallbackStatus,
      'pending': map['pending'] == true || _isPendingStatus(status),
      'raw': map,
    };
  }

  Future<List<Map<String, dynamic>>> _fetchRegistrationsFromStatusApi({
    required String classId,
    required String status,
  }) async {
    final token = await _readToken();

    final url =
        '$_baseUrl/class-registrations/$classId/students/status?page=0&size=100&status=$status';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    debugPrint('REG STATUS API URL -> $url');
    debugPrint('REG STATUS API STATUS -> ${response.statusCode}');
    debugPrint('REG STATUS API BODY -> ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode != 200) return [];

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final List<dynamic> content = _safeList(data);

    return content.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return _mapRegistrationItem(map, status);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAllRegistrationsAndFilter({
    required String classId,
  }) async {
    final token = await _readToken();

    final urls = [
      '$_baseUrl/class-registrations?page=0&size=500',
      '$_baseUrl/class-registrations/$classId/students?page=0&size=500',
      '$_baseUrl/class-registrations/class/$classId?page=0&size=500',
    ];

    final result = <Map<String, dynamic>>[];

    for (final url in urls) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        debugPrint('REG ALL API URL -> $url');
        debugPrint('REG ALL API STATUS -> ${response.statusCode}');
        debugPrint('REG ALL API BODY -> ${utf8.decode(response.bodyBytes)}');

        if (response.statusCode != 200) continue;

        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> content = _safeList(data);

        for (final raw in content) {
          if (raw is! Map) continue;

          final map = Map<String, dynamic>.from(raw);
          final regClassId = _getRegistrationClassId(map);

          if (regClassId != classId) continue;

          result.add(_mapRegistrationItem(map, _getStatus(map)));
        }
      } catch (e) {
        debugPrint('FETCH ALL REG ERROR -> $url -> $e');
      }
    }

    return result;
  }

  Future<void> _loadClassRegistrations(Map<String, dynamic> classItem) async {
    setState(() {
      _selectedClass = classItem;
      _isLoadingRegistrations = true;
      _pendingStudents = [];
      _acceptedStudents = [];
      _errorMessage = null;
    });

    try {
      final classId = classItem['id'].toString();

      final allItems = <Map<String, dynamic>>[];

      for (final status in _pendingStatuses) {
        final items = await _fetchRegistrationsFromStatusApi(
          classId: classId,
          status: status,
        );
        allItems.addAll(items);
      }

      for (final status in _acceptedStatuses) {
        final items = await _fetchRegistrationsFromStatusApi(
          classId: classId,
          status: status,
        );
        allItems.addAll(items);
      }

      final fallbackItems = await _fetchAllRegistrationsAndFilter(
        classId: classId,
      );

      allItems.addAll(fallbackItems);

      final unique = <String, Map<String, dynamic>>{};

      for (final item in allItems) {
        final id = _text(item['registrationId']);
        final sid = _text(item['studentId']);
        final key = id.isNotEmpty ? id : '${item['classId']}_$sid';

        if (key.trim().isEmpty) continue;

        unique[key] = item;
      }

      final pending = <Map<String, dynamic>>[];
      final accepted = <Map<String, dynamic>>[];

      for (final item in unique.values) {
        final status = _getStatus(item);

        if (_isPendingStatus(status)) {
          pending.add(item);
        } else if (_isAcceptedStatus(status)) {
          accepted.add(item);
        }
      }

      setState(() {
        _pendingStudents = pending;
        _acceptedStudents = accepted;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRegistrations = false;
        });
      }
    }
  }

  Future<void> _updateRegistrationStatus({
    required String registrationId,
    required String status,
  }) async {
    if (registrationId.isEmpty) {
      _showMessage(
        'Không xác định được mã đăng ký',
        color: Colors.red,
        icon: Icons.error_outline,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final token = await _readToken();

      if (token.isEmpty) {
        throw Exception('Không tìm thấy access token');
      }

      final urls = [
        '$_baseUrl/class-registrations/$registrationId?status=$status',
        '$_baseUrl/class-registrations/$registrationId/status?status=$status',
      ];

      http.Response? response;

      for (final url in urls) {
        final res = await http.put(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        debugPrint('UPDATE REG URL -> $url');
        debugPrint('UPDATE REG STATUS -> ${res.statusCode}');
        debugPrint('UPDATE REG BODY -> ${utf8.decode(res.bodyBytes)}');

        if (res.statusCode == 200 ||
            res.statusCode == 201 ||
            res.statusCode == 204) {
          response = res;
          break;
        }

        response = res;
      }

      if (response != null &&
          (response.statusCode == 200 ||
              response.statusCode == 201 ||
              response.statusCode == 204)) {
        _showMessage(
          status == 'ACCEPTED'
              ? 'Đã chấp nhận đăng ký'
              : 'Đã cập nhật trạng thái',
          color: Colors.green,
          icon: Icons.check_circle,
        );

        if (_selectedClass != null) {
          await _loadClassRegistrations(_selectedClass!);
        }
      } else {
        throw Exception('Cập nhật trạng thái thất bại');
      }
    } catch (e) {
      _showMessage(
        e.toString().replaceAll('Exception: ', ''),
        color: Colors.red,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _deleteRegistration(String registrationId) async {
    if (registrationId.isEmpty) {
      _showMessage(
        'Không xác định được mã đăng ký',
        color: Colors.red,
        icon: Icons.error_outline,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final token = await _readToken();

      if (token.isEmpty) {
        throw Exception('Không tìm thấy access token');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/class-registrations/$registrationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 202) {
        _showMessage(
          'Xóa đăng ký thành công',
          color: Colors.green,
          icon: Icons.delete_forever,
        );

        if (_selectedClass != null) {
          await _loadClassRegistrations(_selectedClass!);
        }
      } else {
        throw Exception('Xóa đăng ký thất bại (${response.statusCode})');
      }
    } catch (e) {
      _showMessage(
        e.toString().replaceAll('Exception: ', ''),
        color: Colors.red,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _confirmAccept(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Chấp nhận đăng ký',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn có muốn chấp nhận "${item['studentName']}" vào lớp này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chấp nhận'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _updateRegistrationStatus(
        registrationId: item['registrationId'],
        status: 'ACCEPTED',
      );
    }
  }

  Future<void> _confirmDeleteRegistration(
      Map<String, dynamic> item, {
        bool removeFromClass = false,
      }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          removeFromClass ? 'Xóa khỏi lớp' : 'Xóa đăng ký',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          removeFromClass
              ? 'Bạn có chắc muốn xóa "${item['studentName']}" khỏi lớp không?'
              : 'Bạn có chắc muốn xóa lời đăng ký của "${item['studentName']}" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteRegistration(item['registrationId']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 920;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Quản lý user theo lớp',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _fetchMyClasses,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Chờ duyệt (${_pendingStudents.length})'),
            Tab(text: 'Đã vào lớp (${_acceptedStudents.length})'),
          ],
        ),
      ),
      body: _isLoadingClasses
          ? const Center(child: CircularProgressIndicator())
          : _myClasses.isEmpty
          ? Center(
        child: Text(
          _errorMessage ?? 'Bạn chưa có lớp nào để quản lý.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16),
        child: isWide
            ? Row(
          children: [
            Expanded(flex: 4, child: _buildClassPanel()),
            const SizedBox(width: 16),
            Expanded(flex: 6, child: _buildRegistrationPanel()),
          ],
        )
            : Column(
          children: [
            Expanded(flex: 4, child: _buildClassPanel()),
            const SizedBox(height: 16),
            Expanded(flex: 6, child: _buildRegistrationPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildClassPanel() {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            icon: Icons.class_rounded,
            title: 'Danh sách lớp',
            subtitle: '${_myClasses.length} lớp',
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: _myClasses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _myClasses[index];
                final selected = _selectedClass?['id'] == item['id'];

                return Material(
                  color: selected
                      ? AppColors.primary.withOpacity(0.08)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _loadClassRegistrations(item),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : const Color(0xFFE5E7EB),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                            AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item['startDate']} - ${item['endDate']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
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

  Widget _buildRegistrationPanel() {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            icon: Icons.groups_rounded,
            title: _selectedClass == null
                ? 'Quản lý đăng ký'
                : 'Lớp: ${_selectedClass!['title']}',
            subtitle: _selectedClass == null
                ? 'Chọn một lớp để xem đăng ký'
                : 'Duyệt đăng ký và quản lý thành viên lớp',
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoadingRegistrations
                ? const Center(child: CircularProgressIndicator())
                : _selectedClass == null
                ? _buildEmptyState(
              icon: Icons.touch_app_rounded,
              text: 'Hãy chọn một lớp để xem danh sách đăng ký.',
            )
                : _errorMessage != null
                ? _buildEmptyState(
              icon: Icons.error_outline_rounded,
              text: _errorMessage!,
            )
                : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(),
                _buildAcceptedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_pendingStudents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.hourglass_empty_rounded,
        text:
        'Không có sinh viên nào đang chờ duyệt.\nNếu DB đang có status OPENING thì bấm làm mới hoặc chọn lại lớp.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _pendingStudents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _pendingStudents[index];

        return _buildStudentCard(
          item: item,
          statusColor: Colors.orange,
          actions: [
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _confirmAccept(item),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Chấp nhận'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed:
              _isProcessing ? null : () => _confirmDeleteRegistration(item),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Xóa'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAcceptedTab() {
    if (_acceptedStudents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.groups_outlined,
        text: 'Chưa có sinh viên nào được vào lớp.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _acceptedStudents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _acceptedStudents[index];

        return _buildStudentCard(
          item: item,
          statusColor: Colors.green,
          actions: [
            OutlinedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () => _confirmDeleteRegistration(
                item,
                removeFromClass: true,
              ),
              icon: const Icon(Icons.person_remove_alt_1, size: 18),
              label: const Text('Xóa khỏi lớp'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStudentCard({
    required Map<String, dynamic> item,
    required Color statusColor,
    required List<Widget> actions,
  }) {
    final nameText = (item['studentName'] ?? 'U').toString().trim();
    final firstChar = nameText.isNotEmpty ? nameText.characters.first : 'U';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE0E7FF),
                child: Text(
                  firstChar.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['studentName'] ?? 'Chưa có tên',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Student ID: ${item['studentId']}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12.6,
                      ),
                    ),
                    if ((item['registeredAt'] ?? '').toString().isNotEmpty)
                      Text(
                        'Đăng ký lúc: ${item['registeredAt']}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12.4,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  (item['status'] ?? 'UNKNOWN').toString(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String text,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}