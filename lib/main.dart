import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/app_providers.dart';
import 'app/app.dart';

void main() {
  runApp(
    MultiProvider(
      providers: AppProviders.providers,
      child: const MyApp(),
    ),
  );
}
