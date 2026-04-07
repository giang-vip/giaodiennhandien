import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/create_class_viewmodel.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _locationIdController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _locationIdController.dispose();
    super.dispose();
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

  Future<void> _handleCreateClass() async {
    final name = _nameController.text.trim();
    final description = _descController.text.trim();
    final locationText = _locationIdController.text.trim();

    if (name.isEmpty) {
      _showTopNotification(
        context,
        "Vui lòng nhập tên lớp!",
        Colors.orange,
        Icons.warning_amber_rounded,
      );
      return;
    }

    if (locationText.isEmpty) {
      _showTopNotification(
        context,
        "Vui lòng nhập Location ID!",
        Colors.orange,
        Icons.warning_amber_rounded,
      );
      return;
    }

    final int? locationId = int.tryParse(locationText);
    if (locationId == null) {
      _showTopNotification(
        context,
        "Location ID phải là số!",
        Colors.red,
        Icons.error_outline,
      );
      return;
    }

    final success = await context.read<CreateClassViewModel>().createClassAPI(
      title: name,
      description: description,
      locationIds: [locationId],
    );

    if (!mounted) return;

    if (success) {
      _showTopNotification(
        context,
        "Tạo lớp thành công!",
        Colors.green,
        Icons.check_circle,
      );
      Navigator.pop(context);
    } else {
      _showTopNotification(
        context,
        "Lỗi tạo lớp!",
        Colors.red,
        Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CreateClassViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Class'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Class Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationIdController,
              decoration: const InputDecoration(
                labelText: 'Location ID (VD: 1)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            viewModel.isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleCreateClass,
                child: const Text('SAVE CLASS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}