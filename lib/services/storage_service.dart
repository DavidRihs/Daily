import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/meeting.dart';

class StorageService {
  // In dev, Flutter runs on a random port while the API server is on 8080.
  // In production, the Dart server serves both on the same origin — use a
  // relative path so the app works behind any reverse proxy or port.
  static String get _apiBase {
    if (kIsWeb) {
      final base = Uri.base;
      // Dev: Flutter dev server is NOT on 8080, so we must target 8080 explicitly.
      // Production: app is served by the Dart server on the same origin.
      // Dev: Flutter dev server runs on a non-standard port (e.g. 8081, random).
      // Production: served by the Dart server on port 80/443 or 8080 — use
      // a relative path so it works behind any reverse proxy or port mapping.
      const standardPorts = {0, 80, 443, 8080};
      final isDev = !standardPorts.contains(base.port);
      if (isDev) return '${base.scheme}://${base.host}:8080/api';
      return '/api';
    }
    return 'http://localhost:8080/api';
  }

  /// Returns `(meetings, success)`. On network error, returns `([], false)`.
  /// An empty list from the server returns `([], true)`.
  static Future<(List<Meeting>, bool)> loadMeetings() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiBase/meetings'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        final meetings = list
            .map((e) => Meeting.fromJson(e as Map<String, dynamic>))
            .toList();
        return (meetings, true);
      }
    } catch (_) {
      // Server unreachable
    }
    return (const <Meeting>[], false);
  }

  static Future<bool> saveMeetings(List<Meeting> meetings) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_apiBase/meetings'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(meetings.map((m) => m.toJson()).toList()),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
