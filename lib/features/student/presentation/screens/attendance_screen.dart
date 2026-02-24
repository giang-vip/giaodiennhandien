import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/attendance_viewmodel.dart';

class AttendanceScreen extends StatefulWidget {
  final Map<String, dynamic>? classData;
  const AttendanceScreen({super.key, this.classData});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isGpsChecking = true;
  String _gpsStatus = "Đang kiểm tra vị trí GPS...";
  Color _gpsColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _simulateGpsCheck();
  }

  void _simulateGpsCheck() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isGpsChecking = false;
        _gpsStatus = "Vị trí hợp lệ: Cách lớp học 10m";
        _gpsColor = Colors.green;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AttendanceViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Check In')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildGpsCard(),
            const SizedBox(height: 32),
            const Text(
              "FACE ID VERIFICATION",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            _buildFaceIdPreview(),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: (_isGpsChecking || viewModel.isProcessing)
                  ? null
                  : () async {
                      final success = await viewModel.takeAttendance();
                      if (success && context.mounted) {
                        _showSuccessDialog(context);
                      } else if (context.mounted) {
                        _showFailureDialog(context);
                      }
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: viewModel.isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Confirm Attendance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsCard() {
    return Card(
      elevation: 0,
      color: _gpsColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _gpsColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            _isGpsChecking
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.location_on, color: Colors.green),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _gpsStatus,
                style: TextStyle(color: _gpsColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceIdPreview() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 8),
            image: const DecorationImage(
              image: NetworkImage('https://img.freepik.com/free-vector/biometric-recognition-concept_23-2148524430.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        _buildScanningEffect(),
      ],
    );
  }

  Widget _buildScanningEffect() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
      ),
      // Giả lập vệt sáng quét (Simulated scan animation placeholder)
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 80),
        content: const Text(
          'Attendance Recorded Successfully!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(context, AppRoutes.attendanceHistory);
              },
              child: const Text('GO TO HISTORY'),
            ),
          ),
        ],
      ),
    );
  }

  void _showFailureDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.error_outline, color: Colors.red, size: 70),
        content: const Text('Face/Location verification failed. Please try again.'),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Retry')),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Exit'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
