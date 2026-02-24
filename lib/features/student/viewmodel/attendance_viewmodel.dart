import 'dart:math';
import 'package:flutter/material.dart';

class AttendanceRecord {
  final String date;
  final String time;
  final String status; // Present / Absent

  AttendanceRecord({required this.date, required this.time, required this.status});
}

class AttendanceViewModel extends ChangeNotifier {
  final List<AttendanceRecord> _history = [];
  List<AttendanceRecord> get history => _history;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  int get totalPresent => _history.where((r) => r.status == 'Present').length;
  int get totalAbsent => _history.where((r) => r.status == 'Absent').length;
  double get percentage => _history.isEmpty ? 0.0 : (totalPresent / _history.length) * 100;

  Future<bool> takeAttendance() async {
    _isProcessing = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    // Giả lập tỉ lệ thành công 80%
    final isSuccess = Random().nextDouble() < 0.8;

    if (isSuccess) {
      _history.insert(0, AttendanceRecord(
        date: DateTime.now().toString().split(' ')[0],
        time: '${DateTime.now().hour}:${DateTime.now().minute}',
        status: 'Present',
      ));
    }

    _isProcessing = false;
    notifyListeners();
    return isSuccess;
  }
}
