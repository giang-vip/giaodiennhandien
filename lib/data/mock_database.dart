import 'models/app_models.dart';

class MockDatabase {
  // Thêm biến này để lưu ID thật do Backend sinh ra
  static int? currentActiveSessionId;

  static List<AppClassModel> allClasses = [
    AppClassModel(
      id: '1',
      teacherId: 'GV01',
      teacherName: 'Senior Teacher',
      className: 'Lập trình Flutter',
      description: 'Học MVVM và Clean Architecture',
      startTime: '08:00',
      endTime: '10:00',
    ),
  ];

  static List<String> registeredClassIds = [];
}
