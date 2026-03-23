import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/create_class_viewmodel.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _teacherIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _locationIdController = TextEditingController();

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
    final viewModel = context.watch<CreateClassViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Class')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _teacherIdController, decoration: const InputDecoration(labelText: 'Teacher ID (VD: 6)'), keyboardType: TextInputType.number),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Class Name')),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: _locationIdController, decoration: const InputDecoration(labelText: 'Location ID (Phòng học, VD: 1)'), keyboardType: TextInputType.number),
            const SizedBox(height: 32),

            viewModel.isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: () async {
                if (_nameController.text.isNotEmpty && _teacherIdController.text.isNotEmpty && _locationIdController.text.isNotEmpty) {
                  bool success = await context.read<CreateClassViewModel>().createClassAPI(
                    title: _nameController.text,
                    description: _descController.text,
                    teacherId: int.parse(_teacherIdController.text),
                    locationIds: [int.parse(_locationIdController.text)],
                  );

                  if (success && context.mounted) {
                    _showTopNotification(context, "Tạo lớp thành công!", Colors.green, Icons.check_circle);
                    Navigator.pop(context);
                  } else if (context.mounted) {
                    _showTopNotification(context, "Lỗi tạo lớp!", Colors.red, Icons.error_outline);
                  }
                }
              },
              child: const Text('SAVE CLASS'),
            ),
          ],
        ),
      ),
    );
  }
}