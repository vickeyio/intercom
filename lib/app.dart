import 'package:flutter/material.dart';
import 'config/routes.dart';
import 'config/theme.dart';

class IntercomApp extends StatelessWidget {
  const IntercomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Intercom App',
      theme: AppTheme.themeData,
      initialRoute: AppRoutes.roleSelection,
      routes: AppRoutes.routes,
    );
  }
}

