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

  static String _text(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _extractRoomId(Map<String, dynamic> json) {
    final direct = json['roomId'] ??
        json['locationId'] ??
        json['location_id'] ??
        json['room_id'];

    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }

    final locationIds = json['locationIds'];
    if (locationIds is List && locationIds.isNotEmpty) {
      return locationIds.first.toString();
    }

    final locations = json['locations'];
    if (locations is List && locations.isNotEmpty) {
      final first = locations.first;

      if (first is Map && first['id'] != null) {
        return first['id'].toString();
      }

      if (first is Map && first['locationId'] != null) {
        return first['locationId'].toString();
      }

      return first.toString();
    }

    final location = json['location'] ?? json['room'];
    if (location is Map) {
      final id = location['id'] ?? location['locationId'];
      if (id != null) return id.toString();
    }

    return null;
  }

  static double? _extractRadius(Map<String, dynamic> json) {
    return _double(
      json['radius'] ??
          json['radiusMeters'] ??
          json['defaultRadius'] ??
          json['allowedRadius'] ??
          json['location']?['radius'] ??
          json['location']?['radiusMeters'] ??
          json['room']?['radius'] ??
          json['room']?['radiusMeters'],
    );
  }

  factory AppClassModel.fromJson(Map<String, dynamic> json) {
    return AppClassModel(
      id: _text(
        json['id'] ??
            json['classId'] ??
            json['classroomId'] ??
            json['classRoomId'],
      ),
      teacherId: _text(
        json['teacherId'] ??
            json['teacher']?['id'] ??
            json['teacher']?['userId'],
      ),
      teacherName: _text(
        json['teacherName'] ??
            json['teacher']?['fullName'] ??
            json['teacher']?['name'],
      ).isNotEmpty
          ? _text(
        json['teacherName'] ??
            json['teacher']?['fullName'] ??
            json['teacher']?['name'],
      )
          : 'Không rõ giảng viên',
      className: _text(
        json['className'] ??
            json['title'] ??
            json['name'],
      ).isNotEmpty
          ? _text(
        json['className'] ??
            json['title'] ??
            json['name'],
      )
          : 'Lớp học không tên',
      description: _text(json['description']),
      startTime: _text(
        json['startTime'] ??
            json['startDate'],
      ),
      endTime: _text(
        json['endTime'] ??
            json['endDate'],
      ),
      isAttendanceOpen: json['isAttendanceOpen'] == true,
      attendanceDuration: json['attendanceDuration'] is int
          ? json['attendanceDuration']
          : int.tryParse(json['attendanceDuration']?.toString() ?? '') ?? 0,
      roomId: _extractRoomId(json),
      radius: _extractRadius(json),
      attendanceStartTime: json['attendanceStartTime']?.toString(),
      attendanceEndTime: json['attendanceEndTime']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'classId': id,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'className': className,
      'title': className,
      'description': description,
      'startTime': startTime,
      'startDate': startTime,
      'endTime': endTime,
      'endDate': endTime,
      'isAttendanceOpen': isAttendanceOpen,
      'attendanceDuration': attendanceDuration,
      'roomId': roomId,
      'locationId': roomId,
      'radius': radius,
      'radiusMeters': radius,
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

    return DateTime.tryParse(attendanceStartTime!)?.toLocal();
  }

  DateTime? get attendanceEndDateTime {
    if (attendanceEndTime == null || attendanceEndTime!.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(attendanceEndTime!)?.toLocal();
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