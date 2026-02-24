import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_routes.dart';
import '../../../../data/models/app_models.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/class_viewmodel.dart';

class RegisteredClassesScreen extends StatelessWidget {
  const RegisteredClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClassViewModel>();
    final classes = viewModel.registeredClasses;

    return Scaffold(
      appBar: AppBar(title: const Text('My Classes')),
      body: classes.isEmpty
          ? const Center(child: Text("You haven't registered for any classes yet."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final item = classes[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item.className, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            _buildStatusChip(item.isAttendanceOpen),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Teacher: ${item.teacherName}', style: const TextStyle(color: AppColors.textSecondary)),
                        Text('Schedule: ${item.startTime} - ${item.endTime}', style: const TextStyle(color: AppColors.textSecondary)),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: item.isAttendanceOpen
                                    ? () => Navigator.pushNamed(
                                          context,
                                          AppRoutes.attendance,
                                          arguments: {'name': item.className, 'id': item.id},
                                        )
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  item.isAttendanceOpen ? 'TAKE ATTENDANCE (Hurry!)' : 'Attendance Closed',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton.filledTonal(
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.attendanceHistory),
                              icon: const Icon(Icons.history),
                              tooltip: 'History',
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

  Widget _buildStatusChip(bool isOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOpen ? 'Active' : 'Closed',
        style: TextStyle(
          color: isOpen ? Colors.green : Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
