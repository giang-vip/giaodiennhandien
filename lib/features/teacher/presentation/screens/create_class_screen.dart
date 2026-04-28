import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../viewmodel/create_class_viewmodel.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedLocationId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CreateClassViewModel>().fetchLocations();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatApiDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$year-$month-$day';
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;

        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = _endDate ?? _startDate ?? now;
    final first = _startDate ?? DateTime(now.year - 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(now.year + 10),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _showTopNotification(
      BuildContext context,
      String message,
      Color bgColor,
      IconData icon,
      ) {
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
            borderRadius: BorderRadius.circular(14),
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

    if (name.isEmpty) {
      _showTopNotification(
        context,
        'Vui lòng nhập tên lớp!',
        Colors.orange,
        Icons.warning_amber_rounded,
      );
      return;
    }

    if (_selectedLocationId == null || _selectedLocationId!.isEmpty) {
      _showTopNotification(
        context,
        'Vui lòng chọn phòng học!',
        Colors.orange,
        Icons.location_on_outlined,
      );
      return;
    }

    final int? locationId = int.tryParse(_selectedLocationId!);
    if (locationId == null) {
      _showTopNotification(
        context,
        'Location ID không hợp lệ!',
        Colors.red,
        Icons.error_outline,
      );
      return;
    }

    if (_startDate == null) {
      _showTopNotification(
        context,
        'Vui lòng chọn ngày bắt đầu!',
        Colors.orange,
        Icons.date_range,
      );
      return;
    }

    if (_endDate == null) {
      _showTopNotification(
        context,
        'Vui lòng chọn ngày kết thúc!',
        Colors.orange,
        Icons.date_range,
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      _showTopNotification(
        context,
        'Ngày kết thúc phải lớn hơn hoặc bằng ngày bắt đầu!',
        Colors.red,
        Icons.error_outline,
      );
      return;
    }

    final success = await context.read<CreateClassViewModel>().createClassAPI(
      title: name,
      description: description,
      locationId: locationId,
      startDate: _formatApiDate(_startDate!),
      endDate: _formatApiDate(_endDate!),
    );

    if (!mounted) return;

    if (success) {
      _showTopNotification(
        context,
        'Tạo lớp thành công!',
        Colors.green,
        Icons.check_circle,
      );
      Navigator.pop(context);
    } else {
      _showTopNotification(
        context,
        'Lỗi tạo lớp! Vui lòng kiểm tra token hoặc backend.',
        Colors.red,
        Icons.error_outline,
      );
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CreateClassViewModel>();
    final locations = viewModel.locations;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Tạo lớp học',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Tải lại phòng học',
            onPressed: viewModel.isLocationLoading
                ? null
                : () {
              context.read<CreateClassViewModel>().fetchLocations();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
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
                      Icons.meeting_room_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chọn phòng học từ danh sách. Hệ thống sẽ gửi locationId tương ứng khi tạo lớp.',
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
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration(
                  label: 'Tên lớp',
                  hint: 'Ví dụ: Java nâng cao',
                  icon: Icons.class_outlined,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: _inputDecoration(
                  label: 'Mô tả',
                  hint: 'Nhập mô tả ngắn về lớp học',
                  icon: Icons.description_outlined,
                ),
              ),
              const SizedBox(height: 16),
              viewModel.isLocationLoading
                  ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Đang tải danh sách phòng...',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
                  : DropdownButtonFormField<String>(
                value: _selectedLocationId,
                isExpanded: true,
                decoration: _inputDecoration(
                  label: 'Phòng học / vị trí',
                  hint: 'Chọn phòng học',
                  icon: Icons.location_on_outlined,
                ),
                items: locations.map((room) {
                  return DropdownMenuItem<String>(
                    value: room.id,
                    child: Text(
                      'ID ${room.id} - ${room.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: locations.isEmpty
                    ? null
                    : (value) {
                  setState(() {
                    _selectedLocationId = value;
                  });
                },
              ),
              if (!viewModel.isLocationLoading && locations.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Không có dữ liệu phòng. Hãy kiểm tra API /locations hoặc bấm tải lại.',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                readOnly: true,
                onTap: _pickStartDate,
                controller: TextEditingController(text: _formatDate(_startDate)),
                decoration: _inputDecoration(
                  label: 'Ngày bắt đầu',
                  hint: 'Chọn ngày bắt đầu',
                  icon: Icons.calendar_month_outlined,
                ).copyWith(
                  suffixIcon: const Icon(Icons.date_range),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                readOnly: true,
                onTap: _pickEndDate,
                controller: TextEditingController(text: _formatDate(_endDate)),
                decoration: _inputDecoration(
                  label: 'Ngày kết thúc',
                  hint: 'Chọn ngày kết thúc',
                  icon: Icons.event_available_outlined,
                ).copyWith(
                  suffixIcon: const Icon(Icons.date_range),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: viewModel.isLoading ? null : _handleCreateClass,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: viewModel.isLoading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                      : const Text(
                    'LƯU LỚP HỌC',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
