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

  const SetLocationScreen({
    super.key,
    required this.classModel,
  });

  @override
  State<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends State<SetLocationScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  String? _selectedRoomId;
  String? _selectedRoomName;
  final TextEditingController _radiusController = TextEditingController();

  LatLng _currentMapPosition = const LatLng(21.028511, 105.804817);
  double _currentRadius = 50.0;

  @override
  void initState() {
    super.initState();

    _selectedRoomId = widget.classModel.roomId?.toString();

    if (widget.classModel.radius != null && widget.classModel.radius! > 0) {
      _currentRadius = widget.classModel.radius!;
      _radiusController.text = widget.classModel.radius!.toString();
    } else {
      _currentRadius = 50.0;
      _radiusController.text = "50";
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final locVM = context.read<SetLocationViewModel>();

    await locVM.loadInitialData();

    if (!mounted) return;

    // ưu tiên vị trí hiện tại của user khi mới mở màn
    if (locVM.currentPosition != null) {
      _currentMapPosition = LatLng(
        locVM.currentPosition!.latitude,
        locVM.currentPosition!.longitude,
      );

      await _moveCameraToLatLng(_currentMapPosition, 17);
    }

    // nếu lớp đã có roomId lưu trước đó thì nhảy về phòng đã chọn
    if (_selectedRoomId != null && _selectedRoomId!.isNotEmpty) {
      try {
        final savedRoom = locVM.realLocations.firstWhere(
              (r) => r.id.toString() == _selectedRoomId.toString(),
        );
        _selectedRoomName = savedRoom.name;
        _moveCameraToRoom(savedRoom, keepCustomRadius: true);
      } catch (e) {
        debugPrint("LOAD SAVED ROOM ERROR: $e");
      }
    }
  }

  Future<void> _moveCameraToLatLng(LatLng target, double zoom) async {
    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: zoom,
          ),
        ),
      );
    }
  }

  Future<void> _goToCurrentLocation() async {
    final locVM = context.read<SetLocationViewModel>();
    final ok = await locVM.getCurrentLocation();

    if (!mounted) return;

    if (ok && locVM.currentPosition != null) {
      setState(() {
        _currentMapPosition = LatLng(
          locVM.currentPosition!.latitude,
          locVM.currentPosition!.longitude,
        );
        _selectedRoomName = "Vị trí hiện tại";
      });

      await _moveCameraToLatLng(_currentMapPosition, 17);
    } else {
      _showTopNotification(
        context,
        locVM.locationError ?? 'Không lấy được vị trí hiện tại',
        Colors.red,
        Icons.error_outline,
      );
    }
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  void _moveCameraToRoom(RoomModel room, {bool keepCustomRadius = false}) async {
    if (!mounted) return;

    setState(() {
      _currentMapPosition = LatLng(room.latitude, room.longitude);
      _selectedRoomName = room.name;
      _selectedRoomId = room.id.toString();

      if (!keepCustomRadius) {
        _currentRadius = room.defaultRadius > 0 ? room.defaultRadius : 50.0;
        _radiusController.text = _currentRadius.toStringAsFixed(0);
      }
    });

    await _moveCameraToLatLng(_currentMapPosition, 18.5);

    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      Future.delayed(const Duration(milliseconds: 500), () {
        controller.showMarkerInfoWindow(const MarkerId('room_location'));
      });
    }
  }

  void _showTopNotification(
      BuildContext context,
      String message,
      Color bgColor,
      IconData icon,
      ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 160,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locVM = context.watch<SetLocationViewModel>();
    final classVM = context.read<ClassManagementViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text("Set Location: ${widget.classModel.className}"),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _goToCurrentLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: locVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Classroom Mapping',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            if (locVM.isGettingCurrentLocation)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text("Đang lấy vị trí hiện tại..."),
              ),
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.blueAccent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: GoogleMap(
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(
                      target: _currentMapPosition,
                      zoom: 15,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      if (!_mapController.isCompleted) {
                        _mapController.complete(controller);
                      }
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('room_location'),
                        position: _currentMapPosition,
                        infoWindow: InfoWindow(
                          title: _selectedRoomName ?? 'Vị trí hiện tại / phòng học',
                          snippet:
                          'Bán kính hợp lệ: ${_currentRadius.toInt()}m',
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
            const Text(
              '2. Select Room Configuration',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: (_selectedRoomId != null &&
                  locVM.realLocations.any(
                        (r) => r.id.toString() == _selectedRoomId,
                  ))
                  ? _selectedRoomId
                  : null,
              isExpanded: true,
              items: locVM.realLocations.map((r) {
                return DropdownMenuItem<String>(
                  value: r.id.toString(),
                  child: Text(
                    r.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v == null) return;

                final selectedRoom = locVM.realLocations.firstWhere(
                      (r) => r.id.toString() == v.toString(),
                );

                _moveCameraToRoom(selectedRoom);
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.meeting_room_outlined),
                hintText: 'Select a classroom',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '3. Define Attendance Radius',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              onChanged: (val) {
                setState(() {
                  final parsed = double.tryParse(val);
                  _currentRadius =
                  (parsed != null && parsed > 0) ? parsed : 50.0;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                onPressed: () async {
                  if (_selectedRoomId == null || _selectedRoomId!.isEmpty) {
                    _showTopNotification(
                      context,
                      'Vui lòng chọn 1 phòng học!',
                      Colors.red,
                      Icons.error_outline,
                    );
                    return;
                  }

                  final radius =
                      double.tryParse(_radiusController.text) ?? 50.0;

                  if (radius <= 0) {
                    _showTopNotification(
                      context,
                      'Bán kính phải lớn hơn 0!',
                      Colors.red,
                      Icons.error_outline,
                    );
                    return;
                  }

                  try {
                    await classVM.updateClass(
                      widget.classModel.copyWith(
                        roomId: _selectedRoomId,
                        radius: radius,
                      ),
                    );

                    if (!mounted) return;

                    _showTopNotification(
                      context,
                      'Lưu thông tin phòng thành công!',
                      Colors.green,
                      Icons.check_circle,
                    );

                    Navigator.pop(context, true);
                  } catch (e) {
                    if (!mounted) return;
                    _showTopNotification(
                      context,
                      'Lưu thất bại: ${e.toString().replaceAll("Exception: ", "")}',
                      Colors.red,
                      Icons.error_outline,
                    );
                  }
                },
                label: const Text(
                  "SAVE CONFIGURATION",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}