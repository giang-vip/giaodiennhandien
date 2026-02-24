import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class StudentStatsScreen extends StatelessWidget {
  final String className;
  const StudentStatsScreen({super.key, required this.className});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> studentList = [
      {'name': 'Nguyễn Văn A', 'present': 18, 'absent': 2, 'perc': '90%'},
      {'name': 'Trần Thị B', 'present': 20, 'absent': 0, 'perc': '100%'},
      {'name': 'Lê Văn C', 'present': 15, 'absent': 5, 'perc': '75%'},
      {'name': 'Phạm Văn D', 'present': 19, 'absent': 1, 'perc': '95%'},
      {'name': 'Hoàng Văn E', 'present': 10, 'absent': 10, 'perc': '50%'},
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Stats: $className')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.primary.withOpacity(0.1),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryWidget(label: 'Total Students', value: '45'),
                _SummaryWidget(label: 'Avg. Attendance', value: '84%'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: studentList.length,
              itemBuilder: (context, index) {
                final s = studentList[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Present: ${s['present']} | Absent: ${s['absent']}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(s['perc'], 
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text('Rate', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
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
}

class _SummaryWidget extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryWidget({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
