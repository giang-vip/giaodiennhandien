import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../data/models/RoomModel.dart';
import '../../../../data/models/app_models.dart';
import '../../viewmodel/set_location_viewmodel.dart';
import '../../viewmodel/class_management_viewmodel.dart';

class SetLocationScreen extends StatefulWidget {
  final AppClassModel classModel;
  const SetLocationScreen({super.key, required this.classModel});

  @override
  State<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends State<SetLocationScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  String? _selectedRoomId;
  String? _selectedRoomName;
  final _radiusController = TextEditingController();

  LatLng _currentMapPosition = const LatLng(21.028511, 105.804817);
  double _currentRadius = 50.0;

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.classModel.roomId;
    if (widget.classModel.radius != null) {
      _currentRadius = widget.classModel.radius!;
      _radiusController.text = _currentRadius.toString();
    } else {
      _radiusController.text = "50";
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final locVM = context.read<SetLocationViewModel>();
      await locVM.fetchLocations();

      if (_selectedRoomId != null && mounted) {
        try {
          final savedRoom = locVM.realLocations.firstWhere((r) => r.id == _selectedRoomId);
          _selectedRoomName = savedRoom.name;
          _moveCameraToRoom(savedRoom);
        } catch (e) {}
      }
    });
  }

  void _moveCameraToRoom(RoomModel room) async {
    setState(() {
      _currentMapPosition = LatLng(room.latitude, room.longitude);
      _currentRadius = room.defaultRadius;
      _selectedRoomName = room.name;
      _radiusController.text = _currentRadius.toString();
    });

    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _currentMapPosition, zoom: 18.5),
    ));

    // =================================================================
    // ĐÃ SỬA LỖI: Tự động BẬT bong bóng địa chỉ lên thay vì bắt người dùng tự ấn
    // =================================================================
    Future.delayed(const Duration(milliseconds: 500), () {
      controller.showMarkerInfoWindow(const MarkerId('room_location'));
    });
  }

  void _showTopNotification(BuildContext context, String message, Color bgColor, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 160, left: 16, right: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locVM = context.watch<SetLocationViewModel>();
    final classVM = context.read<ClassManagementViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text("Set Location: ${widget.classModel.className}"), elevation: 0),
      body: locVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Classroom Mapping', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),

            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(target: _currentMapPosition, zoom: 15),
                    onMapCreated: (GoogleMapController controller) {
                      _mapController.complete(controller);
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('room_location'),
                        position: _currentMapPosition,
                        infoWindow: InfoWindow(
                            title: _selectedRoomName ?? 'Vị trí phòng học',
                            snippet: 'Bán kính hợp lệ: ${_currentRadius.toInt()}m'
                        ),
                      ),
                    },
                    circles: {
                      Circle(
                        circleId: const CircleId('attendance_radius'),
                        center: _currentMapPosition,
                        radius: _currentRadius,
                        fillColor: Colors.blue.withOpacity(0.2),
                        strokeColor: Colors.blue,
                        strokeWidth: 2,
                      ),
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('2. Select Room Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRoomId,
              isExpanded: true,
              items: locVM.realLocations.map((r) => DropdownMenuItem(
                value: r.id,
                child: Text(r.name, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) {
                setState(() => _selectedRoomId = v);
                final selectedRoom = locVM.realLocations.firstWhere((r) => r.id == v);
                _moveCameraToRoom(selectedRoom);
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.meeting_room_outlined),
                hintText: 'Select a classroom',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            const Text('3. Define Attendance Radius', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              onChanged: (val) {
                setState(() {
                  _currentRadius = double.tryParse(val) ?? 50.0;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'e.g., 50',
                labelText: 'Allowed distance (Radius)',
                prefixIcon: const Icon(Icons.radar_outlined),
                suffixText: 'meters',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined),
                onPressed: () {
                  if (_selectedRoomId != null) {
                    classVM.updateClass(widget.classModel.copyWith(
                      roomId: _selectedRoomId,
                      radius: double.tryParse(_radiusController.text),
                    ));
                    _showTopNotification(context, 'Lưu thông tin phòng thành công!', Colors.green, Icons.check_circle);
                    Navigator.pop(context);
                  } else {
                    _showTopNotification(context, 'Vui lòng chọn 1 phòng học!', Colors.red, Icons.error_outline);
                  }
                },
                label: const Text("SAVE CONFIGURATION", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            )
          ],
        ),
      ),
    );
  }
}