import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/class_management_viewmodel.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../app/app_routes.dart';
import 'set_location_screen.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  Timer? _refreshTimer;
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassManagementViewModel>().fetchClasses();
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeText(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _showTopNotification(
      BuildContext context,
      String message,
      Color bgColor,
      IconData icon,
      ) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 160,
            left: 16,
            right: 16,
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClassManagementViewModel>();

    final keyword = _normalizeText(_searchKeyword);
    final filteredClasses = keyword.isEmpty
        ? viewModel.realClasses
        : viewModel.realClasses.where((item) {
      return _normalizeText(item.className).contains(keyword);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage My Classes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.createClass).then((_) {
                if (context.mounted) {
                  context.read<ClassManagementViewModel>().fetchClasses();
                }
              });
            },
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          await context.read<ClassManagementViewModel>().fetchClasses();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchKeyword = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Tìm kiếm lớp theo tên...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchKeyword.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchKeyword = '';
                    });
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (viewModel.realClasses.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.class_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No classes found.\nCreate one to get started!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (filteredClasses.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không tìm thấy lớp có tên "$_searchKeyword"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredClasses.map((item) {
                final bool isGpsConfigured =
                    item.roomId != null && item.roomId!.isNotEmpty;

                final String remainText =
                viewModel.getRemainingTimeText(item);

                final bool isExpiredButStillMarkedOpen =
                    item.isAttendanceOpen &&
                        (item.remainingAttendanceTime == Duration.zero);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: item.isAttendanceOpen
                          ? Colors.green
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.className,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Time: ${item.startTime} - ${item.endTime}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                try {
                                  await viewModel.deleteClass(item.id);
                                  if (context.mounted) {
                                    _showTopNotification(
                                      context,
                                      'Xóa lớp thành công!',
                                      Colors.green,
                                      Icons.check_circle,
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    _showTopNotification(
                                      context,
                                      e.toString().replaceAll(
                                        "Exception: ",
                                        "",
                                      ),
                                      Colors.red,
                                      Icons.error_outline,
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Attendance is ',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: item.isAttendanceOpen
                                          ? 'OPEN'
                                          : 'CLOSED',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: item.isAttendanceOpen
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Switch(
                              value: item.isAttendanceOpen,
                              onChanged: (value) async {
                                try {
                                  if (value) {
                                    _showTimerDialog(
                                      context,
                                      viewModel,
                                      item.id,
                                    );
                                  } else {
                                    await viewModel.toggleAttendance(
                                      item.id,
                                      0,
                                    );

                                    if (context.mounted) {
                                      _showTopNotification(
                                        context,
                                        'Đóng điểm danh thành công!',
                                        Colors.green,
                                        Icons.check_circle,
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    _showTopNotification(
                                      context,
                                      e.toString().replaceAll(
                                        "Exception: ",
                                        "",
                                      ),
                                      Colors.red,
                                      Icons.error_outline,
                                    );
                                  }
                                }
                              },
                              activeColor: Colors.green,
                            ),
                          ],
                        ),
                        if (item.isAttendanceOpen) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isExpiredButStillMarkedOpen
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isExpiredButStillMarkedOpen
                                    ? Colors.orange.shade300
                                    : Colors.green.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isExpiredButStillMarkedOpen
                                      ? Icons.timer_off_outlined
                                      : Icons.timer_outlined,
                                  size: 18,
                                  color: isExpiredButStillMarkedOpen
                                      ? Colors.orange.shade700
                                      : Colors.green.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isExpiredButStillMarkedOpen
                                        ? 'Phiên điểm danh đã hết giờ, đang đồng bộ đóng...'
                                        : 'Còn lại: $remainText',
                                    style: TextStyle(
                                      color: isExpiredButStillMarkedOpen
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Chip(
                              avatar: Icon(
                                isGpsConfigured
                                    ? Icons.gps_fixed
                                    : Icons.gps_not_fixed,
                                color: isGpsConfigured
                                    ? Colors.white
                                    : Colors.grey,
                                size: 16,
                              ),
                              backgroundColor: isGpsConfigured
                                  ? AppColors.primary
                                  : Colors.grey.shade200,
                              label: Text(
                                isGpsConfigured
                                    ? 'GPS Configured'
                                    : 'No GPS Config',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isGpsConfigured
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (item.isAttendanceOpen)
                              Chip(
                                avatar: const Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                backgroundColor: Colors.green,
                                label: Text(
                                  remainText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SetLocationScreen(
                                      classModel: item,
                                    ),
                                  ),
                                ).then((_) {
                                  if (context.mounted) {
                                    context
                                        .read<ClassManagementViewModel>()
                                        .fetchClasses();
                                  }
                                });
                              },
                              icon: const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                              ),
                              label: const Text('Set Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  void _showTimerDialog(
      BuildContext context,
      ClassManagementViewModel vm,
      String classId,
      ) {
    final controller = TextEditingController(text: "30");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter duration for this attendance session:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: 'minutes',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final minutes = int.tryParse(controller.text.trim()) ?? 30;

              if (minutes <= 0) {
                if (context.mounted) {
                  _showTopNotification(
                    context,
                    'Thời gian mở điểm danh phải lớn hơn 0 phút!',
                    Colors.red,
                    Icons.error_outline,
                  );
                }
                return;
              }

              Navigator.pop(ctx);

              try {
                await vm.toggleAttendance(classId, minutes);

                if (context.mounted) {
                  _showTopNotification(
                    context,
                    'Mở phiên điểm danh thành công!',
                    Colors.green,
                    Icons.check_circle,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _showTopNotification(
                    context,
                    'Lỗi: ${e.toString().replaceAll("Exception: ", "")}',
                    Colors.red,
                    Icons.error_outline,
                  );
                }
              }
            },
            child: const Text('Start Session'),
          ),
        ],
      ),
    );
  }
}
