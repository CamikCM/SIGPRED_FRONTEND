import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import '../data/models/user.dart';
import 'background_location_service.dart';

class AuthService extends GetxService {
  final _storage = const FlutterSecureStorage();

  final Rxn<User> currentUser = Rxn<User>();
  final RxString token = ''.obs;

  Future<AuthService> init() async {
    final storedToken = await _storage.read(key: 'token');
    final storedUser = await _storage.read(key: 'user');

    if (storedToken != null && storedToken.isNotEmpty) {
      token.value = storedToken;
    }

    if (storedUser != null && storedUser.isNotEmpty) {
      try {
        currentUser.value = User.fromJson(jsonDecode(storedUser));
      } catch (_) {
        await clearSession();
      }
    }

    return this;
  }

  Future<void> saveSession(User user, String tok) async {
    currentUser.value = user;
    token.value = tok;

    await _storage.write(key: 'token', value: tok);
    await _storage.write(key: 'user', value: jsonEncode(user.toJson()));
  }

  Future<void> clearSession() async {
    await BackgroundLocationService.stopTracking();
    await BackgroundLocationService.clearTrackingContext();

    currentUser.value = null;
    token.value = '';

    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user');
  }
}
