// lib/preference/preference_handler.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceHandler {
  // =======================
  //       KEY GLOBAL
  // =======================
  static const String tokenKey = "user_token";
  static const String userIdKey = "user_id";
  static const String userNameKey = "user_name";

  static const String _todayAttendanceKeyBase = "attendance_today_json_";
  static const String _absenStatusKeyBase = "absen_status_";

  static const String _profileKey = "saved_profile";

  // in-memory cache
  static Map<String, dynamic>? _cachedProfile;

  // =======================
  //      TOKEN STORAGE
  // =======================
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  // =======================
  //      USER ID / NAME
  // =======================
  static Future<void> saveUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userIdKey, id);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userIdKey);
  }

  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userNameKey, name);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userNameKey);
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userIdKey);
    await prefs.remove(userNameKey);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(tokenKey);
  }

  // =======================
  //   USER SUFFIX HELPER
  // =======================
  static Future<String> _userSuffix() async {
    final uid = await getUserId();
    if (uid != null && uid.isNotEmpty) return uid;

    final token = await getToken();
    if (token == null || token.isEmpty) return "anon";

    return token.length > 12 ? token.substring(0, 12) : token;
  }

  static Future<String> _todayAttendanceKey() async =>
      _todayAttendanceKeyBase + await _userSuffix();

  static Future<String> _absenStatusKey() async =>
      _absenStatusKeyBase + await _userSuffix();

  // =========================================================
  //        ABSEN STATUS (per user)
  // =========================================================
  static Future<void> saveAbsenStatusToday(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _absenStatusKey();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    await prefs.setBool(key, status);
    await prefs.setString("${key}_date", today);
  }

  static Future<bool> getAbsenStatusToday() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _absenStatusKey();

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString("${key}_date");

    if (savedDate != today) {
      await prefs.remove(key);
      await prefs.remove("${key}_date");
      return false;
    }

    return prefs.getBool(key) ?? false;
  }

  static Future<void> clearAbsenStatusToday() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _absenStatusKey();
    await prefs.remove(key);
    await prefs.remove("${key}_date");
  }

  // =========================================================
  //    TODAY ATTENDANCE CACHE (per user)
  // =========================================================
  static Future<void> saveTodayAttendance(Map<String, dynamic> jsonMap) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _todayAttendanceKey();
    await prefs.setString(key, jsonEncode(jsonMap));
  }

  /// Publik helper: update keseluruhan objek today di cache (overwrite)
  static Future<void> updateTodayAttendance(
    Map<String, dynamic> jsonMap,
  ) async {
    await saveTodayAttendance(jsonMap);
  }

  static Future<Map<String, dynamic>?> getTodayAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _todayAttendanceKey();
    final raw = prefs.getString(key);

    if (raw == null) return null;

    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  static Future<void> clearTodayAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _todayAttendanceKey();
    await prefs.remove(key);
  }

  // =========================================================
  //    Convenience: save/read coordinates into today's cache
  // =========================================================

  /// Save check-in coordinates into today's attendance cache.
  /// Will create today's object if not exists (minimal fields).
  static Future<void> saveCheckInCoords(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _todayAttendanceKey();
    final raw = prefs.getString(key);

    Map<String, dynamic> map;
    if (raw == null) {
      map = <String, dynamic>{
        'attendance_date': DateTime.now().toIso8601String().substring(0, 10),
        'check_in_lat': lat,
        'check_in_lng': lng,
      };
    } else {
      try {
        map = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {
        map = <String, dynamic>{};
      }
      map['check_in_lat'] = lat;
      map['check_in_lng'] = lng;
    }

    await prefs.setString(key, jsonEncode(map));
  }

  /// Save check-out coordinates into today's attendance cache.
  static Future<void> saveCheckOutCoords(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _todayAttendanceKey();
    final raw = prefs.getString(key);

    Map<String, dynamic> map;
    if (raw == null) {
      map = <String, dynamic>{
        'attendance_date': DateTime.now().toIso8601String().substring(0, 10),
        'check_out_lat': lat,
        'check_out_lng': lng,
      };
    } else {
      try {
        map = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {
        map = <String, dynamic>{};
      }
      map['check_out_lat'] = lat;
      map['check_out_lng'] = lng;
    }

    await prefs.setString(key, jsonEncode(map));
  }

  /// Return coordinates saved for today (any of the four keys can be null)
  /// keys: check_in_lat, check_in_lng, check_out_lat, check_out_lng
  static Future<Map<String, double?>> getTodayCoords() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _todayAttendanceKey();
    final raw = prefs.getString(key);

    double? tryParseNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        return parsed;
      }
      return null;
    }

    if (raw == null)
      return {
        'check_in_lat': null,
        'check_in_lng': null,
        'check_out_lat': null,
        'check_out_lng': null,
      };

    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      return {
        'check_in_lat': tryParseNum(map['check_in_lat']),
        'check_in_lng': tryParseNum(map['check_in_lng']),
        'check_out_lat': tryParseNum(map['check_out_lat']),
        'check_out_lng': tryParseNum(map['check_out_lng']),
      };
    } catch (_) {
      return {
        'check_in_lat': null,
        'check_in_lng': null,
        'check_out_lat': null,
        'check_out_lng': null,
      };
    }
  }

  // =========================================================
  //        PROFILE CACHE (persist foto + nama)
  // =========================================================
  static Future<void> saveProfile(Map<String, dynamic> profileJson) async {
    final prefs = await SharedPreferences.getInstance();

    final str = jsonEncode(profileJson);
    await prefs.setString(_profileKey, str);

    // update in-memory cache
    _cachedProfile = Map<String, dynamic>.from(profileJson);

    // update quick access fields
    if (profileJson['name'] != null) {
      await prefs.setString(userNameKey, profileJson['name'].toString());
    }
    if (profileJson['id'] != null) {
      await prefs.setString(userIdKey, profileJson['id'].toString());
    }
  }

  static Future<Map<String, dynamic>?> getSavedProfile() async {
    if (_cachedProfile != null) return _cachedProfile;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);

    if (raw == null) return null;

    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      _cachedProfile = map;
      return map;
    } catch (_) {
      await prefs.remove(_profileKey);
      _cachedProfile = null;
      return null;
    }
  }

  static Map<String, dynamic>? getSavedProfileSync() {
    return _cachedProfile;
  }

  static Future<void> clearSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    _cachedProfile = null;
  }

  // =========================================================
  //          LOGOUT BEHAVIOR (UPDATED)
  //
  //  NOTE: by default we *preserve* today's attendance cache on logout so
  //  the app can still show last-known "Absen Hari Ini" while the user
  //  logs back in or when offline. If you want to clear attendance at
  //  logout, pass preserveAttendance: false.
  // =========================================================
  static Future<void> clearAllOnLogout({
    bool preserveProfile = true,
    bool preserveAttendance = true, // default: keep attendance cache
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // compute suffix while token/user id still available
    final suf = await _userSuffix();

    // only remove attendance cache if explicitly requested
    if (!preserveAttendance) {
      await prefs.remove(_todayAttendanceKeyBase + suf);
      await prefs.remove(_absenStatusKeyBase + suf);
      await prefs.remove("${_absenStatusKeyBase + suf}_date");
    }

    // clear token + basic user data
    await prefs.remove(tokenKey);
    await prefs.remove(userIdKey);
    await prefs.remove(userNameKey);

    // clear profile only if NOT preserved
    if (!preserveProfile) {
      await prefs.remove(_profileKey);
      _cachedProfile = null;
    }
  }
}
