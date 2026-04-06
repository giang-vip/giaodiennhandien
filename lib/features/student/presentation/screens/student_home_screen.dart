import 'package:flutter/material.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_colors.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.studentHome),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildFeatureCard(
              context,
              'Available Classes',
              'Browse and register for new classes',
              Icons.search,
              AppRoutes.classList,
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              context,
              'Registered Classes',
              'View your classes and take attendance',
              Icons.collections_bookmark,
              AppRoutes.registeredClasses,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String subtitle, IconData icon, String route) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}
