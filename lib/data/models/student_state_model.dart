// Class phụ để chứa dữ liệu thống kê của 1 Sinh viên
class StudentStatModel {
  final String studentName;
  final String studentId;
  int present;
  int absent;

  StudentStatModel({required this.studentName, required this.studentId, this.present = 0, this.absent = 0});

  int get total => present + absent;
  double get percent => total == 0 ? 0 : (present / total) * 100;
}