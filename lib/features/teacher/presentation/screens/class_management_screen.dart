import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/teacher_viewmodel.dart';
import '../../../../data/models/app_models.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../app/app_routes.dart';
import 'set_location_screen.dart';

class ClassManagementScreen extends StatelessWidget {
  const ClassManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TeacherViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage My Classes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create new class',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.createClass),
          ),
        ],
      ),
      body: viewModel.myClasses.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No classes found.\nCreate one to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: viewModel.myClasses.length,
        itemBuilder: (context, index) {
          final item = viewModel.myClasses[index];
          final bool isGpsConfigured = item.roomId != null && item.radius != null;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: item.isAttendanceOpen ? Colors.green : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hàng 1: Tên lớp và nút Xóa (Sử dụng Expanded an toàn)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.className,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Time: ${item.startTime} - ${item.endTime}',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => viewModel.deleteClass(item.id),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Hàng 2: Bật tắt điểm danh
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Attendance is ',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              TextSpan(
                                text: item.isAttendanceOpen ? 'OPEN' : 'CLOSED',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: item.isAttendanceOpen ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Switch(
                        value: item.isAttendanceOpen,
                        onChanged: (value) {
                          if (value) {
                            _showTimerDialog(context, viewModel, item.id);
                          } else {
                            viewModel.toggleAttendance(item.id, 0);
                          }
                        },
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  if (item.isAttendanceOpen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Ends in: ${item.attendanceDuration} minutes (simulated)',
                        style: TextStyle(color: Colors.green[700], fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Hàng 3: Trạng thái GPS và nút Set Location (Sử dụng Wrap để chống lỗi tràn màn hình)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Chip(
                        avatar: Icon(
                          isGpsConfigured ? Icons.gps_fixed : Icons.gps_not_fixed,
                          color: isGpsConfigured ? Colors.white : Colors.grey,
                          size: 16,
                        ),
                        backgroundColor: isGpsConfigured ? AppColors.primary : Colors.grey.shade200,
                        label: Text(
                          isGpsConfigured ? 'GPS Configured' : 'No GPS Config',
                          style: TextStyle(
                            fontSize: 12,
                            color: isGpsConfigured ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SetLocationScreen(classModel: item)),
                          );
                        },
                        icon: const Icon(Icons.location_on_outlined, size: 16),
                        label: const Text('Set Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTimerDialog(BuildContext context, TeacherViewModel vm, String classId) {
    final controller = TextEditingController(text: "30");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text) ?? 30;
              vm.toggleAttendance(classId, minutes);
              Navigator.pop(context);
            },
            child: const Text('Start Session'),
          ),
        ],
      ),
    );
  }
}