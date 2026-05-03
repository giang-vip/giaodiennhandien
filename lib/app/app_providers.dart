import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../features/auth/viewmodel/auth_viewmodel.dart';
import '../features/student/viewmodel/attendance_history_viewmodel.dart';
import '../features/student/viewmodel/class_list_viewmodel.dart';
import '../features/student/viewmodel/registered_classes_viewmodel.dart';
import '../features/student/viewmodel/attendance_viewmodel.dart';

import '../features/teacher/viewmodel/class_management_viewmodel.dart';
import '../features/teacher/viewmodel/create_class_viewmodel.dart';
import '../features/teacher/viewmodel/set_location_viewmodel.dart';
import '../features/teacher/viewmodel/student_stats_viewmodel.dart';
import '../features/teacher/viewmodel/teacher_home_viewmodel.dart';
import '../features/teacher/viewmodel/teacher_viewmodel.dart';

class AppProviders {
  static List<SingleChildWidget> get providers {
    return [
      ChangeNotifierProvider(create: (_) => AuthViewModel()),

      ChangeNotifierProvider(create: (_) => ClassListViewModel()),
      ChangeNotifierProvider(create: (_) => RegisteredClassesViewModel()),
      ChangeNotifierProvider(create: (_) => AttendanceViewModel()),
      ChangeNotifierProvider(create: (_) => AttendanceHistoryViewModel()),

      ChangeNotifierProvider(create: (_) => TeacherViewModel()),

      ChangeNotifierProvider(create: (_) => ClassManagementViewModel()),
      ChangeNotifierProvider(create: (_) => TeacherHomeViewModel()),
      ChangeNotifierProvider(create: (_) => CreateClassViewModel()),
      ChangeNotifierProvider(create: (_) => SetLocationViewModel()),
      ChangeNotifierProvider(create: (_) => StudentStatsViewModel()),
    ];
  }
}
