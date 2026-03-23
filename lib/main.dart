import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/app_providers.dart';
import 'app/app.dart';

void main() {
  // 🔥 DÒNG PHÉP THUẬT: Đảm bảo Flutter và các thư viện (như SharedPreferences) đã sẵn sàng 100% trước khi vẽ giao diện
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: AppProviders.providers,
      child: const MyApp(),
    ),
  );
}
