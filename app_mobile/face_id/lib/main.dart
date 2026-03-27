import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'screens/camera_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/enrollment_screen.dart';
import 'screens/login_screen.dart';
import 'screens/schedules_screen.dart';
import 'screens/success_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FaceIDApp());
}

class FaceIDApp extends StatelessWidget {
  const FaceIDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face-ID Edge AI',
      debugShowCheckedModeBanner: false,
      initialRoute: LoginScreen.routeName,
      routes: {
        LoginScreen.routeName: (_) => const LoginScreen(),
        DashboardScreen.routeName: (_) => const DashboardScreen(),
        CameraScreen.routeName: (_) => const CameraScreen(),
        SuccessScreen.routeName: (_) => const SuccessScreen(),
        SchedulesScreen.routeName: (_) => const SchedulesScreen(),
        EnrollmentScreen.routeName: (_) => const EnrollmentScreen(),
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.deepBlue,
          primary: AppColors.deepBlue,
          secondary: AppColors.successGreen,
          surface: AppColors.surface,
          background: AppColors.background,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.deepBlue,
          foregroundColor: AppColors.onDeepBlue,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
