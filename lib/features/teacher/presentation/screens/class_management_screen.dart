import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/class_management_viewmodel.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../app/app_routes.dart';
import 'set_location_screen.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassManagementViewModel>().fetchClasses();
    });
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
                  fontSize: 14,
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClassManagementViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage My Classes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.createClass).then((_) {
                if (context.mounted) {
                  context.read<ClassManagementViewModel>().fetchClasses();
                }
              });
            },
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : viewModel.realClasses.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.class_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No classes found.\nCreate one to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: viewModel.realClasses.length,
        itemBuilder: (context, index) {
          final item = viewModel.realClasses[index];
          final bool isGpsConfigured =
              item.roomId != null && item.roomId!.isNotEmpty;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: item.isAttendanceOpen
                    ? Colors.green
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.className,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Time: ${item.startTime} - ${item.endTime}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () async {
                          try {
                            print(
                              "DELETE CLICKED: classId=${item.id}",
                            );
                            await viewModel.deleteClass(item.id);
                            if (context.mounted) {
                              _showTopNotification(
                                context,
                                'Xóa lớp thành công!',
                                Colors.green,
                                Icons.check_circle,
                              );
                            }
                          } catch (e) {
                            print("DELETE ERROR UI: $e");
                            if (context.mounted) {
                              _showTopNotification(
                                context,
                                e.toString().replaceAll(
                                  "Exception: ",
                                  "",
                                ),
                                Colors.red,
                                Icons.error_outline,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Attendance is ',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              TextSpan(
                                text: item.isAttendanceOpen
                                    ? 'OPEN'
                                    : 'CLOSED',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: item.isAttendanceOpen
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Switch(
                        value: item.isAttendanceOpen,
                        onChanged: (value) async {
                          print(
                            "SWITCH CLICKED: classId=${item.id}, value=$value, isOpen=${item.isAttendanceOpen}, roomId=${item.roomId}",
                          );

                          try {
                            if (value) {
                              print(
                                "OPEN DIALOG FOR CLASS: ${item.id}",
                              );
                              _showTimerDialog(
                                context,
                                viewModel,
                                item.id,
                              );
                            } else {
                              print(
                                "TRY CLOSE ATTENDANCE FOR CLASS: ${item.id}",
                              );
                              await viewModel.toggleAttendance(
                                item.id,
                                0,
                              );
                              print(
                                "CLOSE ATTENDANCE DONE FOR CLASS: ${item.id}",
                              );

                              if (context.mounted) {
                                _showTopNotification(
                                  context,
                                  'Đóng điểm danh thành công!',
                                  Colors.green,
                                  Icons.check_circle,
                                );
                              }
                            }
                          } catch (e) {
                            print("SWITCH ERROR: $e");
                            if (context.mounted) {
                              _showTopNotification(
                                context,
                                e.toString().replaceAll(
                                  "Exception: ",
                                  "",
                                ),
                                Colors.red,
                                Icons.error_outline,
                              );
                            }
                          }
                        },
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  if (item.isAttendanceOpen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Đang mở điểm danh...',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Chip(
                        avatar: Icon(
                          isGpsConfigured
                              ? Icons.gps_fixed
                              : Icons.gps_not_fixed,
                          color: isGpsConfigured
                              ? Colors.white
                              : Colors.grey,
                          size: 16,
                        ),
                        backgroundColor: isGpsConfigured
                            ? AppColors.primary
                            : Colors.grey.shade200,
                        label: Text(
                          isGpsConfigured
                              ? 'GPS Configured'
                              : 'No GPS Config',
                          style: TextStyle(
                            fontSize: 12,
                            color: isGpsConfigured
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          print(
                            "OPEN SET LOCATION SCREEN: classId=${item.id}, roomId=${item.roomId}",
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SetLocationScreen(
                                classModel: item,
                              ),
                            ),
                          ).then((_) {
                            if (context.mounted) {
                              print(
                                "RETURNED FROM SET LOCATION -> REFRESH CLASSES",
                              );
                              context
                                  .read<ClassManagementViewModel>()
                                  .fetchClasses();
                            }
                          });
                        },
                        icon: const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                        ),
                        label: const Text('Set Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTimerDialog(
      BuildContext context,
      ClassManagementViewModel vm,
      String classId,
      ) {
    final controller = TextEditingController(text: "30");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter duration for this attendance session:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: 'minutes',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              print("OPEN SESSION DIALOG CANCELLED: classId=$classId");
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final minutes = int.tryParse(controller.text) ?? 30;
              print(
                "START SESSION BUTTON CLICKED: classId=$classId, minutes=$minutes",
              );

              Navigator.pop(ctx);

              try {
                await vm.toggleAttendance(classId, minutes);
                print("TOGGLE ATTENDANCE DONE: classId=$classId");

                if (context.mounted) {
                  _showTopNotification(
                    context,
                    'Mở phiên điểm danh thành công!',
                    Colors.green,
                    Icons.check_circle,
                  );
                }
              } catch (e) {
                print("START SESSION ERROR: $e");
                if (context.mounted) {
                  _showTopNotification(
                    context,
                    'Lỗi: ${e.toString().replaceAll("Exception: ", "")}',
                    Colors.red,
                    Icons.error_outline,
                  );
                }
              }
            },
            child: const Text('Start Session'),
          ),
        ],
      ),
    );
  }
}