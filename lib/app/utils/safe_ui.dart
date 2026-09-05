import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SafeUi {
  static void snackbar(
    String title,
    String message, {
    SnackPosition position = SnackPosition.TOP,
  }) {
    final text = '$title: $message';
    debugPrint(text);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final context = Get.context ?? Get.key.currentContext;
        if (context == null) return;

        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) return;

        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
            content: Text(
              '$title\n$message',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      } catch (e) {
        debugPrint('SafeUi snackbar omitido: $e');
      }
    });
  }
}
