import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'presentation/screens/dashboard_screen.dart';

void main() {
  runApp(const SmartOverdoseDetectorApp());
}

class SmartOverdoseDetectorApp extends StatelessWidget {
  const SmartOverdoseDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Overdose Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF60A5FA),
          secondary: const Color(0xFF10B981),
          error: const Color(0xFFEF4444),
          surface: const Color(0xFF131929),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
