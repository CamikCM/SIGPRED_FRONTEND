import 'package:get/get.dart';

import 'tabs/home_tab_view.dart';
import 'tabs/all_tab_view.dart';
import 'tabs/history_tab_view.dart';
import 'tabs/logout_tab_view.dart';

import 'package:flutter/widgets.dart';

class HomeController extends GetxController {
  final currentIndex = 0.obs;

  final tabs = <Widget>[
    const HomeTabView(),
    const HistoryTabView(),
    const AllTabView(),
    const LogoutTabView(),
  ];

  String get appBarTitle {
    switch (currentIndex.value) {
      case 0:
        return "Home";
      case 1:
        return "Historial";
      case 2:
        return "Todos";
      case 3:
        return "Cerrar Sesión";
      default:
        return "Tracking";
    }
  }

  void onTabTapped(int index) => currentIndex.value = index;
}
