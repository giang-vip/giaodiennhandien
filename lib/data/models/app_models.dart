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

class RoomModel {
  final String id;
  final String name;

  RoomModel({
    required this.id,
    required this.name,
  });
}
