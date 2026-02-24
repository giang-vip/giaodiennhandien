import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../features/auth/viewmodel/auth_viewmodel.dart';
import '../features/student/viewmodel/class_viewmodel.dart';
import '../features/student/viewmodel/attendance_viewmodel.dart';
import '../features/teacher/viewmodel/teacher_viewmodel.dart';

class AppProviders {
  static List<SingleChildWidget> get providers {
    return [
      ChangeNotifierProvider(create: (_) => AuthViewModel()),
      ChangeNotifierProvider(create: (_) => ClassViewModel()),
      ChangeNotifierProvider(create: (_) => AttendanceViewModel()),
      ChangeNotifierProvider(create: (_) => TeacherViewModel()),
    ];
  }
}
