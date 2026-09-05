import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/auth_service.dart';
import '../../../utils/app_theme.dart';
import 'supervisor_dashboard_controller.dart';
import 'supervisor_dashboard_view.dart';
import 'supervisor_mobile_more_view.dart';
import 'supervisor_mobile_tracking_view.dart';

class SupervisorHomeView extends StatefulWidget {
  const SupervisorHomeView({super.key});

  @override
  State<SupervisorHomeView> createState() => _SupervisorHomeViewState();
}

class _SupervisorHomeViewState extends State<SupervisorHomeView> {
  int currentIndex = 0;
  int _pageRevision = 0;

  Widget _buildCurrentPage() {
    switch (currentIndex) {
      case 0:
        return SupervisorDashboardView(onOpenMap: () => _selectDestination(1));
      case 1:
        return const SupervisorMobileTrackingView();
      case 2:
        return const SupervisorMobileMoreView();
      default:
        return const SizedBox.shrink();
    }
  }

  String get title {
    switch (currentIndex) {
      case 0:
        return 'Inicio';
      case 1:
        return 'Mapa';
      case 2:
        return 'Más';
      default:
        return 'Supervisor';
    }
  }

  void _selectDestination(int index) {
    if (index == currentIndex) return;

    setState(() {
      currentIndex = index;
      _pageRevision = 0;
    });

    if (index == 0 && Get.isRegistered<SupervisorDashboardController>()) {
      Future.microtask(
        () => Get.find<SupervisorDashboardController>().load(refresh: true),
      );
    }
  }

  void _refreshCurrent() {
    if (currentIndex == 0 &&
        Get.isRegistered<SupervisorDashboardController>()) {
      Get.find<SupervisorDashboardController>().load(refresh: true);
      return;
    }

    if (currentIndex == 1) {
      setState(() => _pageRevision += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final user = auth.currentUser.value;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
              user?.name ?? 'Supervisor',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          if (currentIndex != 2)
            IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshCurrent,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: KeyedSubtree(
        key: ValueKey('supervisor-tab-$currentIndex-$_pageRevision'),
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          height: 64,
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
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              selectedIcon: Icon(Icons.more_horiz_rounded),
              label: 'Más',
            ),
          ],
        ),
      ),
    );
  }
}
