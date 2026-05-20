import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
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
  final TextEditingController _radiusController = TextEditingController();

  String? _selectedRoomId;
  String? _selectedRoomName;

  LatLng _currentMapPosition = const LatLng(21.028511, 105.804817);
  double _currentRadius = 50.0;

  String get _classKey => widget.classModel.id;

  String get _savedRoomKey => 'class_${_classKey}_room';
  String get _savedLocationKey => 'class_${_classKey}_location';
  String get _savedRadiusKey => 'class_${_classKey}_radius';

  @override
  void initState() {
    super.initState();

    _selectedRoomId = widget.classModel.roomId?.toString();

    if (widget.classModel.radius != null && widget.classModel.radius! > 0) {
      _currentRadius = widget.classModel.radius!;
      _radiusController.text = widget.classModel.radius!.toStringAsFixed(0);
    } else {
      _currentRadius = 50.0;
      _radiusController.text = '50';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadInitialData();
    });
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();

    final savedRoomId = prefs.getString(_savedRoomKey) ??
        prefs.getString(_savedLocationKey) ??
        prefs.getString('saved_room_id_$_classKey') ??
        prefs.getString('location_$_classKey');

    final savedRadius = prefs.getDouble(_savedRadiusKey) ??
        prefs.getDouble('saved_radius_$_classKey');

    if (savedRoomId != null && savedRoomId.trim().isNotEmpty) {
      _selectedRoomId = savedRoomId.trim();
    }

    if (savedRadius != null && savedRadius > 0) {
      _currentRadius = savedRadius;
      _radiusController.text = savedRadius.toStringAsFixed(0);
    }
  }

  Future<void> _saveLocalConfig({
    required String roomId,
    required double radius,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_savedRoomKey, roomId);
    await prefs.setString(_savedLocationKey, roomId);
    await prefs.setString('location_$_classKey', roomId);
    await prefs.setString('saved_room_id_$_classKey', roomId);

    await prefs.setDouble(_savedRadiusKey, radius);
    await prefs.setDouble('saved_radius_$_classKey', radius);
  }

  Future<void> _loadInitialData() async {
    final locVM = context.read<SetLocationViewModel>();

    await _loadSavedConfig();
    await locVM.loadInitialData();

    if (!mounted) return;

    if (_selectedRoomId != null && _selectedRoomId!.isNotEmpty) {
      try {
        final savedRoom = locVM.realLocations.firstWhere(
              (room) => room.id.toString() == _selectedRoomId.toString(),
        );

        await _moveCameraToRoom(savedRoom, keepCustomRadius: true);
        return;
      } catch (e) {
        debugPrint('LOAD SAVED ROOM ERROR: $e');
      }
    }

    if (locVM.currentPosition != null) {
      setState(() {
        _currentMapPosition = LatLng(
          locVM.currentPosition!.latitude,
          locVM.currentPosition!.longitude,
        );
      });

      await _moveCameraToLatLng(_currentMapPosition, 17);
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
        _selectedRoomName = 'Vị trí hiện tại';
      });

      await _moveCameraToLatLng(_currentMapPosition, 17);
    } else {
      _showTopNotification(
        locVM.locationError ?? 'Không lấy được vị trí hiện tại',
        Colors.red,
        Icons.error_outline,
      );
    }
  }

  Future<void> _moveCameraToRoom(
      RoomModel room, {
        bool keepCustomRadius = false,
      }) async {
    if (!mounted) return;

    setState(() {
      _selectedRoomId = room.id.toString();
      _selectedRoomName = room.name;
      _currentMapPosition = LatLng(room.latitude, room.longitude);

      if (!keepCustomRadius) {
        _currentRadius = room.defaultRadius > 0 ? room.defaultRadius : 50.0;
        _radiusController.text = _currentRadius.toStringAsFixed(0);
      }
    });

    await _moveCameraToLatLng(_currentMapPosition, 18.5);

    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      Future.delayed(const Duration(milliseconds: 400), () {
        controller.showMarkerInfoWindow(const MarkerId('room_location'));
      });
    }
  }

  void _showTopNotification(String message, Color bgColor, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
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

  Future<void> _saveConfiguration() async {
    if (_selectedRoomId == null || _selectedRoomId!.isEmpty) {
      _showTopNotification(
        'Vui lòng chọn 1 phòng học!',
        Colors.red,
        Icons.error_outline,
      );
      return;
    }

    final radius = double.tryParse(_radiusController.text.trim()) ?? 0;

    if (radius <= 0) {
      _showTopNotification(
        'Bán kính phải lớn hơn 0!',
        Colors.red,
        Icons.error_outline,
      );
      return;
    }

    try {
      final updatedClass = widget.classModel.copyWith(
        roomId: _selectedRoomId,
        radius: radius,
      );

      await _saveLocalConfig(
        roomId: _selectedRoomId!,
        radius: radius,
      );

      await context.read<ClassManagementViewModel>().updateClass(updatedClass);

      if (!mounted) return;

      _showTopNotification(
        'Lưu thông tin phòng thành công!',
        Colors.green,
        Icons.check_circle,
      );

      Navigator.pop(context, updatedClass);
    } catch (e) {
      if (!mounted) return;

      _showTopNotification(
        'Lưu thất bại: ${e.toString().replaceAll('Exception: ', '')}',
        Colors.red,
        Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locVM = context.watch<SetLocationViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Set Location: ${widget.classModel.className}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Vị trí hiện tại',
            onPressed: locVM.isGettingCurrentLocation ? null : _goToCurrentLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: locVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chọn phòng học và bán kính cho lớp này. Khi mở điểm danh, sinh viên phải ở trong bán kính hợp lệ.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (locVM.isGettingCurrentLocation)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Đang lấy vị trí hiện tại...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
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
                          title: _selectedRoomName ?? 'Vị trí phòng học',
                          snippet: 'Bán kính hợp lệ: ${_currentRadius.toInt()}m',
                        ),
                      ),
                    },
                    circles: {
                      Circle(
                        circleId: const CircleId('attendance_radius'),
                        center: _currentMapPosition,
                        radius: _currentRadius,
                        fillColor: AppColors.primary.withOpacity(0.18),
                        strokeColor: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chọn phòng học',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: (_selectedRoomId != null &&
                  locVM.realLocations.any(
                        (room) => room.id.toString() == _selectedRoomId,
                  ))
                  ? _selectedRoomId
                  : null,
              isExpanded: true,
              items: locVM.realLocations.map((room) {
                return DropdownMenuItem<String>(
                  value: room.id.toString(),
                  child: Text(
                    'ID ${room.id} - ${room.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: locVM.realLocations.isEmpty
                  ? null
                  : (value) {
                if (value == null) return;

                final selectedRoom = locVM.realLocations.firstWhere(
                      (room) => room.id.toString() == value.toString(),
                );

                _moveCameraToRoom(selectedRoom);
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.meeting_room_outlined),
                hintText: 'Chọn phòng học',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            if (locVM.realLocations.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Không có danh sách phòng học. Hãy kiểm tra API /locations hoặc token đăng nhập.',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Bán kính điểm danh',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  final parsed = double.tryParse(value);
                  _currentRadius = parsed != null && parsed > 0 ? parsed : 50.0;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Ví dụ: 50',
                labelText: 'Khoảng cách cho phép',
                prefixIcon: const Icon(Icons.radar_outlined),
                suffixText: 'mét',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined),
                onPressed: _saveConfiguration,
                label: const Text(
                  'LƯU CẤU HÌNH',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
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