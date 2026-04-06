class RoomModel {
  final String id;
  final String name;
  final double latitude;   // ĐÃ THÊM: Vĩ độ của phòng học
  final double longitude;  // ĐÃ THÊM: Kinh độ của phòng học
  final double defaultRadius; // ĐÃ THÊM: Bán kính mặc định từ Backend

  RoomModel({
    required this.id,
    required this.name,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.defaultRadius = 50.0,
  });
}