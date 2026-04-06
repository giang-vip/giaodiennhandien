class AppClassModel {
  final String id;
  final String teacherId;
  final String teacherName;
  final String className;
  final String description;
  final String startTime;
  final String endTime;
  final bool isAttendanceOpen;
  final int attendanceDuration;
  final String? roomId;
  final double? radius;

  AppClassModel({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.className,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.isAttendanceOpen = false,
    this.attendanceDuration = 0,
    this.roomId,
    this.radius,
  });

  // ===========================================================================
  // 1. Hàm đúc dữ liệu từ JSON (Map) của Backend sang Object Flutter
  // ===========================================================================
  factory AppClassModel.fromJson(Map<String, dynamic> json) {
    return AppClassModel(
      // Dùng toString() để tránh lỗi nếu Backend trả về kiểu int cho ID
      id: json['id']?.toString() ?? '',
      teacherId: json['teacherId']?.toString() ?? '',
      teacherName: json['teacherName'] ?? 'Không rõ giảng viên',
      className: json['className'] ?? 'Lớp học không tên',
      description: json['description'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      isAttendanceOpen: json['isAttendanceOpen'] ?? false,
      attendanceDuration: json['attendanceDuration'] ?? 0,
      roomId: json['roomId']?.toString(),
      // Xử lý số thực (double) cẩn thận để tránh lỗi type 'int' is not a subtype of 'double'
      radius: json['radius'] != null ? (json['radius'] as num).toDouble() : null,
    );
  }

  // ===========================================================================
  // 2. Hàm chuyển đổi ngược lại từ Object sang JSON (để gửi lên Backend)
  // ===========================================================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'className': className,
      'description': description,
      'startTime': startTime,
      'endTime': endTime,
      'isAttendanceOpen': isAttendanceOpen,
      'attendanceDuration': attendanceDuration,
      'roomId': roomId,
      'radius': radius,
    };
  }

  // ===========================================================================
  // 3. Hàm tạo bản sao (Giữ nguyên các giá trị cũ nếu không truyền giá trị mới)
  // ===========================================================================
  AppClassModel copyWith({
    String? id,
    String? teacherId,
    String? teacherName,
    String? className,
    String? description,
    String? startTime,
    String? endTime,
    bool? isAttendanceOpen,
    int? attendanceDuration,
    String? roomId,
    double? radius,
  }) {
    return AppClassModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      className: className ?? this.className,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAttendanceOpen: isAttendanceOpen ?? this.isAttendanceOpen,
      attendanceDuration: attendanceDuration ?? this.attendanceDuration,
      roomId: roomId ?? this.roomId,
      radius: radius ?? this.radius,
    );
  }
}