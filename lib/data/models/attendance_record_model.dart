// Model phụ chứa dữ liệu
class AttendanceRecordModel {
  final String date;
  final String time;
  final String status;
  final String sessionId; // Dùng để chống trùng lặp

  AttendanceRecordModel({required this.date, required this.time, required this.status, required this.sessionId});
}