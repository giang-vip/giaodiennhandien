import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/teacher_viewmodel.dart';
import '../../../../data/models/app_models.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _idController = TextEditingController();
  final _teacherIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Class')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _teacherIdController, decoration: const InputDecoration(labelText: 'Teacher ID')),
            TextField(controller: _idController, decoration: const InputDecoration(labelText: 'Class ID')),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Class Name')),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: _startController, decoration: const InputDecoration(labelText: 'Start Time (e.g. 08:00)')),
            TextField(controller: _endController, decoration: const InputDecoration(labelText: 'End Time (e.g. 10:00)')),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  final newClass = AppClassModel(
                    id: _idController.text,
                    teacherId: _teacherIdController.text,
                    teacherName: 'Senior Teacher',
                    className: _nameController.text,
                    description: _descController.text,
                    startTime: _startController.text,
                    endTime: _endController.text,
                  );
                  context.read<TeacherViewModel>().addClass(newClass);
                  Navigator.pop(context);
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
