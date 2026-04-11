class AppClassModel {
  static const Object _unset = Object();

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

  final String? attendanceStartTime;
  final String? attendanceEndTime;

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
    this.attendanceStartTime,
    this.attendanceEndTime,
  });

  factory AppClassModel.fromJson(Map<String, dynamic> json) {
    return AppClassModel(
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
      radius: json['radius'] != null ? (json['radius'] as num).toDouble() : null,
      attendanceStartTime: json['attendanceStartTime']?.toString(),
      attendanceEndTime: json['attendanceEndTime']?.toString(),
    );
  }

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
      'attendanceStartTime': attendanceStartTime,
      'attendanceEndTime': attendanceEndTime,
    };
  }

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
    Object? roomId = _unset,
    Object? radius = _unset,
    Object? attendanceStartTime = _unset,
    Object? attendanceEndTime = _unset,
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
      roomId: identical(roomId, _unset) ? this.roomId : roomId as String?,
      radius: identical(radius, _unset) ? this.radius : radius as double?,
      attendanceStartTime: identical(attendanceStartTime, _unset)
          ? this.attendanceStartTime
          : attendanceStartTime as String?,
      attendanceEndTime: identical(attendanceEndTime, _unset)
          ? this.attendanceEndTime
          : attendanceEndTime as String?,
    );
  }

  DateTime? get attendanceStartDateTime {
    if (attendanceStartTime == null || attendanceStartTime!.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(attendanceStartTime!);
  }

  DateTime? get attendanceEndDateTime {
    if (attendanceEndTime == null || attendanceEndTime!.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(attendanceEndTime!);
  }

  bool get isAttendanceExpired {
    final end = attendanceEndDateTime;
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  Duration? get remainingAttendanceTime {
    final end = attendanceEndDateTime;
    if (end == null) return null;

    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return Duration.zero;
    return diff;
  }
}