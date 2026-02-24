import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/app_models.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/teacher_viewmodel.dart';

class SetLocationScreen extends StatefulWidget {
  final AppClassModel classModel;
  const SetLocationScreen({super.key, required this.classModel});

  @override
  State<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends State<SetLocationScreen> {
  String? _selectedRoomId;
  final _radiusController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.classModel.roomId;
    if (widget.classModel.radius != null) {
      _radiusController.text = widget.classModel.radius.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<TeacherViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text("Set Location: ${widget.classModel.className}"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Classroom Mapping',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            _buildMapPlaceholder(),
            const SizedBox(height: 24),
            const Text(
              '2. Select Room Configuration',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRoomId,
              items: vm.rooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
              onChanged: (v) => setState(() => _selectedRoomId = v),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.meeting_room_outlined),
                hintText: 'Select a classroom',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '3. Define Attendance Radius',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
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
                  vm.updateClass(widget.classModel.copyWith(
                    roomId: _selectedRoomId,
                    radius: double.tryParse(_radiusController.text),
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location configuration saved!')),
                  );
                  Navigator.pop(context);
                },
                label: const Text(
                  "SAVE CONFIGURATION",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.greyLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 70, color: Colors.blueGrey.shade300),
          const SizedBox(height: 12),
          Text(
            'Google Maps Simulation',
            style: TextStyle(color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'GPS coordinates will be captured here',
            style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
