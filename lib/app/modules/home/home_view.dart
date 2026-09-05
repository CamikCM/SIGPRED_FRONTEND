import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../utils/app_theme.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      return Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: FadeInDown(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.appBarTitle),
                Text(
                  'SIGPRED',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Refrescar',
              onPressed: () => Get.forceAppUpdate(),
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              ),
              onPressed: () => Get.changeThemeMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: controller.tabs[controller.currentIndex.value],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).navigationBarTheme.backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: controller.currentIndex.value,
                onDestinationSelected: controller.onTabTapped,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(
                      Icons.home_rounded,
                      color: SigmaColors.primary,
                    ),
                    label: 'Inicio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.route_outlined),
                    selectedIcon: Icon(
                      Icons.route_rounded,
                      color: SigmaColors.primary,
                    ),
                    label: 'Historial',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.groups_2_outlined),
                    selectedIcon: Icon(
                      Icons.groups_2_rounded,
                      color: SigmaColors.primary,
                    ),
                    label: 'Todos',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.logout_rounded),
                    selectedIcon: Icon(
                      Icons.logout_rounded,
                      color: SigmaColors.primary,
                    ),
                    label: 'Salir',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
