import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/app_models.dart';
import '../../../data/mock_database.dart';

class TeacherViewModel extends ChangeNotifier {
  final List<RoomModel> _rooms = [
    RoomModel(id: 'R01', name: 'Phòng 101 - Tòa A'),
    RoomModel(id: 'R02', name: 'Phòng 202 - Tòa B'),
    RoomModel(id: 'R03', name: 'Lab 01 - Tòa C'),
  ];

  List<AppClassModel> get myClasses => MockDatabase.allClasses;
  List<RoomModel> get rooms => _rooms;

  void addClass(AppClassModel newClass) {
    MockDatabase.allClasses.add(newClass);
    notifyListeners();
  }

  void updateClass(AppClassModel updatedClass) {
    int index = MockDatabase.allClasses.indexWhere((c) => c.id == updatedClass.id);
    if (index != -1) {
      MockDatabase.allClasses[index] = updatedClass;
      notifyListeners();
    }
  }

  void deleteClass(String id) {
    MockDatabase.allClasses.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void toggleAttendance(String classId, int minutes) {
    int index = MockDatabase.allClasses.indexWhere((c) => c.id == classId);
    if (index != -1) {
      final bool newState = !MockDatabase.allClasses[index].isAttendanceOpen;
      MockDatabase.allClasses[index] = MockDatabase.allClasses[index].copyWith(
        isAttendanceOpen: newState,
        attendanceDuration: minutes,
      );
      
      if (newState && minutes > 0) {
        Timer(Duration(minutes: minutes), () {
          _autoCloseAttendance(classId);
        });
      }
      notifyListeners();
    }
  }

  void _autoCloseAttendance(String classId) {
    int index = MockDatabase.allClasses.indexWhere((c) => c.id == classId);
    if (index != -1) {
      MockDatabase.allClasses[index] = MockDatabase.allClasses[index].copyWith(isAttendanceOpen: false);
      notifyListeners();
    }
  }
}
