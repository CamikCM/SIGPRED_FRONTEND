import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/auth_service.dart';
import '../../../utils/app_theme.dart';
import 'historial_visitador_controller.dart';
import 'historial_visitador_view.dart';
import 'mapa_ruta_visitador_view.dart';
import 'visitador_mas_view.dart';
import 'visitador_operativo_view.dart';

class VisitadorHomeView extends StatefulWidget {
  const VisitadorHomeView({super.key});

  @override
  State<VisitadorHomeView> createState() => _VisitadorHomeViewState();
}

class _VisitadorHomeViewState extends State<VisitadorHomeView> {
  int currentIndex = 0;
  int _pageRevision = 0;

  void _selectDestination(int index) {
    if (index == currentIndex) return;

    debugPrint('🧭 Visitador navegación: $currentIndex -> $index');

    setState(() {
      currentIndex = index;
      _pageRevision++;
    });

    if (index == 2 && Get.isRegistered<HistorialVisitadorController>()) {
      Future.microtask(
        () => Get.find<HistorialVisitadorController>().cargarHistorial(),
      );
    }
  }

  Widget _buildCurrentPage() {
    switch (currentIndex) {
      case 0:
        return VisitadorOperativoView(onOpenRoute: () => _selectDestination(1));
      case 1:
        return MapaRutaVisitadorView(onOpenHome: () => _selectDestination(0));
      case 2:
        return const HistorialVisitadorView();
      case 3:
        return const VisitadorMasView();
      default:
        return VisitadorOperativoView(onOpenRoute: () => _selectDestination(1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final user = auth.currentUser.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (user?.name ?? 'Visitador médico').trim();
    final initial = name.isEmpty ? 'V' : name.substring(0, 1).toUpperCase();

    return Scaffold(
      extendBody: false,
      appBar: currentIndex == 1
          ? null
          : AppBar(
              toolbarHeight: 68,
              titleSpacing: 16,
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: SigmaColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: SigmaColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SIGPRED',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: isDark ? 'Usar modo claro' : 'Usar modo oscuro',
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                  onPressed: () => Get.changeThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
      body: KeyedSubtree(
        key: ValueKey('visitador-page-$currentIndex-$_pageRevision'),
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: _selectDestination,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Mi ruta',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_rounded),
              selectedIcon: Icon(Icons.menu_rounded),
              label: 'Más',
            ),
          ],
        ),
      ),
    );
  }
}
