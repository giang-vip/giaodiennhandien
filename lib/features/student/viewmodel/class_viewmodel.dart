import 'package:flutter/material.dart';
import '../../../data/models/app_models.dart';
import '../../../data/mock_database.dart';

class ClassViewModel extends ChangeNotifier {
  List<AppClassModel> get availableClasses => MockDatabase.allClasses
      .where((c) => !MockDatabase.registeredClassIds.contains(c.id))
      .toList();

  List<AppClassModel> get registeredClasses => MockDatabase.allClasses
      .where((c) => MockDatabase.registeredClassIds.contains(c.id))
      .toList();

  void registerClass(String classId) {
    if (!MockDatabase.registeredClassIds.contains(classId)) {
      MockDatabase.registeredClassIds.add(classId);
      notifyListeners();
    }
  }

  void refresh() {
    notifyListeners();
  }
}
