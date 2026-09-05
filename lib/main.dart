import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/global_binding.dart';
import 'app/services/auth_service.dart';
import 'app/services/background_location_service.dart';
import 'app/services/sync_service.dart';
import 'app/utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Los servicios de segundo plano y sincronización con SQLite
  // corresponden únicamente a la aplicación móvil.
  if (!kIsWeb) {
    await BackgroundLocationService.initializeService();
  }

  final authService = await AuthService().init();
  Get.put<AuthService>(authService, permanent: true);

  if (!kIsWeb) {
    final syncService = await SyncService().init();
    Get.put<SyncService>(syncService, permanent: true);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIGPRED',
      initialBinding: GlobalBinding(),
      initialRoute: auth.token.value.isNotEmpty
          ? Routes.roleHome
          : Routes.login,
      getPages: AppPages.pages,
      themeMode: ThemeMode.system,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: SigmaColors.primary,
      brightness: brightness,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0B1020)
          : SigmaColors.surface,
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : SigmaColors.ink,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : SigmaColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF111827) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE0E4EE),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE0E4EE),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: SigmaColors.primary, width: 1.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SigmaColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: SigmaColors.primary.withOpacity(0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 76,
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        indicatorColor: SigmaColors.primary.withOpacity(0.13),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
