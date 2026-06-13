import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../constants/app_constants.dart';

class OneSignalService {
  static const _appId = '3a49f279-28c0-4202-8295-40803253b8b7';

  /// Call after user logs in — links this device to the user in backend + OneSignal
  static Future<void> registerUser(String userId) async {
    try {
      // Tag the user in OneSignal so we can target them by userId
      OneSignal.User.addTagWithKey('user_id', userId);

      // Get the OneSignal subscription ID (player ID)
      final subId = OneSignal.User.pushSubscription.id;
      if (subId == null || subId.isEmpty) {
        debugPrint('[OneSignal] No subscription ID yet — will retry on next launch');
        // Listen for when subscription becomes available
        OneSignal.User.pushSubscription.addObserver((state) {
          final newId = state.current.id;
          if (newId != null && newId.isNotEmpty) {
            _saveToBackend(userId, newId);
          }
        });
        return;
      }
      await _saveToBackend(userId, subId);
    } catch (e) {
      debugPrint('[OneSignal] registerUser error: $e');
    }
  }

  static Future<void> _saveToBackend(String userId, String playerId) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/onesignal/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'player_id': playerId}),
      ).timeout(const Duration(seconds: 10));
      debugPrint('[OneSignal] register → ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('[OneSignal] _saveToBackend error: $e');
    }
  }

  /// Call on logout — untag the user
  static void clearUser() {
    try {
      OneSignal.User.removeTag('user_id');
      OneSignal.logout();
    } catch (_) {}
  }

  static String get appId => _appId;
}
