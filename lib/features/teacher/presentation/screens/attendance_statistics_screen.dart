import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_routes.dart';
import '../../viewmodel/teacher_viewmodel.dart';
import 'student_stats_screen.dart';

class AttendanceStatisticsScreen extends StatelessWidget {
  const AttendanceStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TeacherViewModel>();
    final classes = viewModel.myClasses;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Class for Statistics')),
      body: classes.isEmpty
          ? const Center(child: Text('No classes found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final item = classes[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(child: Icon(Icons.class_)),
                    title: Text(item.className, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Time: ${item.startTime} - ${item.endTime}'),
                    trailing: const Icon(Icons.analytics_outlined, color: Colors.blue),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentStatsScreen(className: item.className),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
