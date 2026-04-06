import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/teacher_home_viewmodel.dart'; // Đổi import

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherHomeViewModel>().fetchDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TeacherHomeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildSummaryHeader(viewModel.totalClasses, viewModel.openClasses),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildFeatureCard(context, 'Create New Class', Icons.add_circle_outline, Colors.blue, AppRoutes.createClass),
                  _buildFeatureCard(context, 'Manage My Classes', Icons.class_outlined, Colors.orange, AppRoutes.manageClasses),
                  _buildFeatureCard(context, 'View Statistics', Icons.bar_chart_outlined, Colors.green, AppRoutes.attendanceStats),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(int totalClasses, int openClasses) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const Text('Overview', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total Classes', totalClasses.toString()),
              _buildSummaryItem('Attendance Open', openClasses.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, IconData icon, Color color, String route) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Sau khi tạo lớp hoặc quản lý lớp xong quay lại -> Tự reload Dashboard
          Navigator.pushNamed(context, route).then((_) {
            if(context.mounted) context.read<TeacherHomeViewModel>().fetchDashboardData();
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 30, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 30, color: color)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}