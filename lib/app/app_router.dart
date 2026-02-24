import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/student/presentation/screens/student_home_screen.dart';
import '../features/student/presentation/screens/class_list_screen.dart';
import '../features/student/presentation/screens/registered_classes_screen.dart';
import '../features/student/presentation/screens/attendance_screen.dart';
import '../features/student/presentation/screens/attendance_history_screen.dart';
import '../features/teacher/presentation/screens/teacher_home_screen.dart';
import '../features/teacher/presentation/screens/create_class_screen.dart';
import '../features/teacher/presentation/screens/class_management_screen.dart';
import '../features/teacher/presentation/screens/attendance_statistics_screen.dart';
import '../features/teacher/presentation/screens/student_stats_screen.dart';
import '../features/teacher/presentation/screens/set_location_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.studentHome:
        return MaterialPageRoute(builder: (_) => const StudentHomeScreen());
      case AppRoutes.classList:
        return MaterialPageRoute(builder: (_) => const ClassListScreen());
      case AppRoutes.registeredClasses:
        return MaterialPageRoute(builder: (_) => const RegisteredClassesScreen());
      case AppRoutes.attendance:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(builder: (_) => AttendanceScreen(classData: args));
      case AppRoutes.attendanceHistory:
        return MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen());
      case AppRoutes.teacherHome:
        return MaterialPageRoute(builder: (_) => const TeacherHomeScreen());
      case AppRoutes.createClass:
        return MaterialPageRoute(builder: (_) => const CreateClassScreen());
      case AppRoutes.manageClasses:
        return MaterialPageRoute(builder: (_) => const ClassManagementScreen());
      case AppRoutes.attendanceStats:
        return MaterialPageRoute(builder: (_) => const AttendanceStatisticsScreen());
      case AppRoutes.studentStats:
        final className = settings.arguments as String? ?? 'Class';
        return MaterialPageRoute(builder: (_) => StudentStatsScreen(className: className));
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}