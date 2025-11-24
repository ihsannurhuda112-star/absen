import 'dart:convert';
import 'package:absensi_san/constant/endpoint.dart';
import 'package:absensi_san/models/attendance_history.dart';
import 'package:absensi_san/models/attendance_statistics.dart';
import 'package:absensi_san/models/attendance_today.dart';
import 'package:absensi_san/models/profile_model.dart';
import 'package:absensi_san/models/register_model.dart';
import 'package:absensi_san/models/login_model.dart';
import 'package:absensi_san/preference/preference_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:io';

class AuthAPI {
  static String baseUrl = "https://appabsensi.mobileprojp.com";

  // ganti fungsi registerUser lama dengan yang ini
  static Future<RegisterModel> registerUser({
    required String name,
    required String email,
    required String password,
    required String jenisKelamin,
    required String
    profilePhoto, // ekspektasi: dataURI "data:image/..;base64,....." atau bare base64
    required int batchId,
    required int trainingId,
  }) async {
    final url = Uri.parse("$baseUrl/api/register");

    // helper parse JSON safe
    Map<String, dynamic>? tryParseJson(String body) {
      try {
        final p = jsonDecode(body);
        if (p is Map<String, dynamic>) return p;
        return null;
      } catch (_) {
        return null;
      }
    }

    // 1) coba kirim sebagai JSON (base64 payload)
    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "name": name,
          "email": email,
          "password": password,
          "jenis_kelamin": jenisKelamin,
          "profile_photo": profilePhoto,
          "batch_id": batchId,
          "training_id": trainingId,
        }),
      );

      print("DEBUG register (JSON) status : ${response.statusCode}");
      print("DEBUG register (JSON) body   : ${response.body}");

      // deteksi apakah response adalah JSON sukses
      final contentType = response.headers['content-type'] ?? '';
      final looksJson =
          contentType.contains('application/json') ||
          response.body.trim().startsWith('{');

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          looksJson) {
        return RegisterModel.fromJson(jsonDecode(response.body));
      }

      // Jika bukan JSON atau bukan 200/201, lanjut ke multipart fallback
    } catch (e) {
      print("WARN register (JSON) failed: $e");
      // lanjut ke multipart
    }

    // 2) fallback: kirim multipart (decode base64 -> bytes)
    try {
      // extract base64 part jika diberikan sebagai data-uri "data:image/png;base64,...."
      String base64Part = profilePhoto;
      if (profilePhoto.contains(',')) {
        base64Part = profilePhoto.split(',').last;
      }
      // decode base64 => bytes
      final Uint8List bytes = base64Decode(base64Part);

      final req = http.MultipartRequest('POST', url);
      req.headers.addAll({
        "Accept": "application/json",
        // jangan set Content-Type karena MultipartRequest akan set sendiri
      });

      // fields
      req.fields['name'] = name;
      req.fields['email'] = email;
      req.fields['password'] = password;
      req.fields['jenis_kelamin'] = jenisKelamin;
      req.fields['batch_id'] = batchId.toString();
      req.fields['training_id'] = trainingId.toString();

      // file field: gunakan nama field yang backend harapkan (saya gunakan 'profile_photo')
      req.files.add(
        http.MultipartFile.fromBytes(
          'profile_photo',
          bytes,
          filename: 'profile_photo.png',
          // contentType can be added if you import http_parser and want to set it
        ),
      );

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      print("DEBUG register (multipart) status : ${resp.statusCode}");
      print("DEBUG register (multipart) body   : ${resp.body}");

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final parsed = tryParseJson(resp.body);
        if (parsed != null) {
          return RegisterModel.fromJson(parsed);
        } else {
          throw Exception(
            "Register gagal: server tidak mengembalikan JSON (body: ${resp.body})",
          );
        }
      } else {
        final parsed = tryParseJson(resp.body);
        final msg = (parsed != null && parsed['message'] != null)
            ? parsed['message']
            : resp.body;
        throw Exception(
          "Register gagal (multipart) HTTP ${resp.statusCode}: $msg",
        );
      }
    } catch (e) {
      throw Exception("Register gagal: $e");
    }
  }

  // ============================
  //           LOGIN USER
  // ============================
  static Future<LoginModel> loginUser({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse("$baseUrl/api/login");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      return LoginModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Login gagal: ${response.body}");
    }
  }

  // ============================
  //      REQUEST RESET OTP
  // ============================
  static Future<bool> requestResetPassword({required String email}) async {
    final url = Uri.parse("$baseUrl/api/forgot-password");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({"email": email}),
    );

    print("FORGOT STATUS : ${response.statusCode}");
    print("FORGOT BODY   : ${response.body}");

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception("Gagal mengirim OTP: ${response.body}");
    }
  }

  // ============================
  //   VERIFY OTP + RESET PASSWORD
  // ============================
  static Future<bool> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final url = Uri.parse("$baseUrl/api/reset-password");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({"email": email, "otp": otp, "password": newPassword}),
    );

    print("VERIFY STATUS : ${response.statusCode}");
    print("VERIFY BODY   : ${response.body}");

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception("Reset password gagal: ${response.body}");
    }
  }

  // ============================
  //        ABSEN CHECK-IN
  // ============================
  static Future<bool> absenCheckIn({
    required double lat,
    required double lng,
    required String address,
  }) async {
    final now = DateTime.now();
    final token = await PreferenceHandler.getToken();

    final body = {
      "attendance_date": DateFormat("yyyy-MM-dd").format(now),
      "check_in": DateFormat("HH:mm").format(now),
      "check_in_lat": lat,
      "check_in_lng": lng,
      "check_in_address": address,
      "status": "masuk",
    };

    final response = await http.post(
      Uri.parse("$baseUrl/api/absen/check-in"),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    print("DEBUG check-in status : ${response.statusCode}");
    print("DEBUG check-in body   : ${response.body}");

    return response.statusCode == 200;
  }

  // ============================
  //        ABSEN CHECK-OUT
  // ============================
  static Future<bool> absenCheckOut({
    required double lat,
    required double lng,
    required String address,
  }) async {
    final now = DateTime.now();
    final token = await PreferenceHandler.getToken();

    final body = {
      "attendance_date": DateFormat("yyyy-MM-dd").format(now),
      "check_out": DateFormat("HH:mm").format(now),
      "check_out_lat": lat,
      "check_out_lng": lng,
      "check_out_location": "$lat, $lng",
      "check_out_address": address,
    };

    final response = await http.post(
      Uri.parse("$baseUrl/api/absen/check-out"),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    print("DEBUG check-out status : ${response.statusCode}");
    print("DEBUG check-out body   : ${response.body}");

    return response.statusCode == 200;
  }

  // ============================
  //     GET TODAY STATISTICS
  // ============================
  static Future<AttendanceToday?> getToday() async {
    final now = DateTime.now();
    final todayStr = DateFormat("yyyy-MM-dd").format(now);

    final token = await PreferenceHandler.getToken();

    final url = Uri.parse(
      "$baseUrl/api/absen/stats?start=$todayStr&end=$todayStr",
    );

    final response = await http.get(
      url,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        "Accept": "application/json",
      },
    );

    print("DEBUG getToday status : ${response.statusCode}");
    print("DEBUG getToday body   : ${response.body}");

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = body['data'];

      if (data is List && data.isNotEmpty) {
        return AttendanceToday.fromJson(data[0]);
      }
      return null;
    } else {
      return null;
    }
  }

  // ============================
  //     **NEW** FLEXIBLE STATISTICS
  // ============================
  static Future<AttendanceStatistics> getStatistik({
    String? start,
    String? end,
  }) async {
    final Uri uri = (start != null || end != null)
        ? Uri.parse("$baseUrl/api/absen/stats").replace(
            queryParameters: {
              if (start != null) 'start': start,
              if (end != null) 'end': end,
            },
          )
        : Uri.parse("$baseUrl/api/absen/stats");

    final token = await PreferenceHandler.getToken();

    final response = await http.get(
      uri,
      headers: {
        if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
        "Accept": "application/json",
      },
    );

    print("DEBUG getStatistik url : $uri");
    print("DEBUG getStatistik status : ${response.statusCode}");
    print("DEBUG getStatistik body : ${response.body}");

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] ?? {};

      return AttendanceStatistics(
        totalAbsen: data['total_absen'] ?? 0,
        totalMasuk: data['total_masuk'] ?? 0,
        totalIzin: data['total_izin'] ?? 0,
        sudahAbsenHariIni: data['sudah_absen_hari_ini'] ?? false,
      );
    } else {
      try {
        final body = jsonDecode(response.body);
        final msg = body is Map && body['message'] != null
            ? body['message']
            : response.body;
        throw Exception('HTTP ${response.statusCode}: $msg');
      } catch (_) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    }
  }

  // ============================
  //          HISTORY ABSEN
  // ============================
  static Future<List<AttendanceHistory>> fetchHistory({
    String? start,
    String? end,
  }) async {
    final token = await PreferenceHandler.getToken();

    final uri = Uri.parse("$baseUrl/api/absen/history").replace(
      queryParameters: {
        if (start != null) 'start': start,
        if (end != null) 'end': end,
      },
    );

    final headers = <String, String>{
      HttpHeaders.authorizationHeader: 'Bearer $token',
      'Accept': 'application/json',
    };

    final response = await http.get(uri, headers: headers);

    print("DEBUG fetchHistory status : ${response.statusCode}");
    print("DEBUG fetchHistory body   : ${response.body}");

    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body);
        final msg = body is Map && body['message'] != null
            ? body['message']
            : response.body;
        throw Exception('HTTP ${response.statusCode}: $msg');
      } catch (_) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (body['data'] == null) {
      final msg = body['message'] ?? 'Unknown error';
      throw Exception(msg);
    }

    final dynData = body['data'];
    if (dynData is List == false) return [];

    final List<dynamic> list = dynData as List<dynamic>;
    return list
        .map((e) => AttendanceHistory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // returns a Map with keys: success (bool), message (String), attendance (Map?)
  // does NOT throw on normal HTTP errors; returns success: false instead.
  // Keeps using form-encoded body (as your backend currently expects).
  static Future<Map<String, dynamic>> submitIzin({
    required String date,
    required String alasan,
  }) async {
    final url = Uri.parse(Endpoint.izin);
    final token = await PreferenceHandler.getToken();

    try {
      final res = await http.post(
        url,
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
          // jangan set Content-Type kalau body adalah Map -> http package akan
          // gunakan application/x-www-form-urlencoded secara default
        },
        body: {"date": date, "alasan_izin": alasan},
      );

      // safe parse JSON
      dynamic parsed;
      try {
        parsed = jsonDecode(res.body);
      } catch (_) {
        parsed = res.body;
      }

      // sukses
      if (res.statusCode == 200 || res.statusCode == 201) {
        final String message = (parsed is Map && parsed['message'] != null)
            ? parsed['message'].toString()
            : 'Sukses';

        final dynamic data = (parsed is Map) ? parsed['data'] : null;
        Map<String, dynamic>? attendanceMap;
        if (data is Map<String, dynamic>) {
          attendanceMap = Map<String, dynamic>.from(data);
        }

        return {
          'success': true,
          'message': message,
          'attendance': attendanceMap, // bisa null
        };
      }

      // non-200: kembalikan message dari body bila ada
      final String errMsg = (parsed is Map && parsed['message'] != null)
          ? parsed['message'].toString()
          : 'HTTP ${res.statusCode}: ${res.body}';

      return {'success': false, 'message': errMsg, 'status': res.statusCode};
    } catch (e) {
      // network / unexpected error
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Helper: submit izin and cache attendance locally if returned by server.
  /// Returns the same Map structure as submitIzin but also saves attendance into
  /// PreferenceHandler when available.
  static Future<Map<String, dynamic>> submitIzinAndCache({
    required String date,
    required String alasan,
  }) async {
    final result = await submitIzin(date: date, alasan: alasan);

    if (result['success'] == true && result['attendance'] != null) {
      try {
        final Map<String, dynamic> attendanceMap = Map<String, dynamic>.from(
          result['attendance'],
        );
        // save attendance object to today's cache
        await PreferenceHandler.saveTodayAttendance(attendanceMap);
        // mark has absen today (so UI reflects it)
        await PreferenceHandler.saveAbsenStatusToday(true);
      } catch (e) {
        print('WARN: gagal cache attendance setelah submitIzin: $e');
      }
    }

    return result;
  }

  // ============================
  //      GET PROFILE (updated)
  // ============================
  static Future<ProfileData> getProfile() async {
    final token = await PreferenceHandler.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/profile'),
      headers: {
        if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final parsed = jsonDecode(response.body);

      // simpan ke cache (parsed['data'] biasanya Map)
      try {
        if (parsed is Map && parsed['data'] != null && parsed['data'] is Map) {
          final Map<String, dynamic> dataMap = Map<String, dynamic>.from(
            parsed['data'] as Map,
          );
          await PreferenceHandler.saveProfile(dataMap);
        }
      } catch (_) {}

      return ProfileModel.fromJson(parsed).data!;
    } else {
      throw Exception('Gagal mengambil profil (HTTP ${response.statusCode})');
    }
  }

  // ============================
  // EDIT PROFILE (PUT /edit-profile)
  // ============================
  static Future<bool> editProfile({
    required String name,
    required String email,
  }) async {
    final token = await PreferenceHandler.getToken();
    final uri = Uri.parse("$baseUrl/api/profile");

    final response = await http.put(
      uri,
      headers: {
        if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"name": name, "email": email}),
    );

    print("DEBUG editProfile status : ${response.statusCode}");
    print("DEBUG editProfile body   : ${response.body}");

    if (response.statusCode == 200) {
      // update local cache jika backend mengembalikan 'data'
      try {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        if (parsed['data'] != null && parsed['data'] is Map) {
          final Map<String, dynamic> dataMap = Map<String, dynamic>.from(
            parsed['data'] as Map,
          );
          await PreferenceHandler.saveProfile(dataMap);
        }
      } catch (e) {
        print("WARN: gagal update cache profile: $e");
      }
      return true;
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // di dalam class AuthAPI

  /// Upload profile photo as base64 payload (PUT or POST sesuai backend)
  static Future<bool> editProfilePhotoBase64({
    required File imageFile,
    String endpoint = '/api/profile/photo',
    String mimeType = 'image/png',
    bool usePut = true,
  }) async {
    final token = await PreferenceHandler.getToken();
    final uri = Uri.parse("$baseUrl$endpoint");

    // baca file bytes & encode base64
    final bytes = await imageFile.readAsBytes();
    final b64 = base64Encode(bytes);
    final payload = "data:$mimeType;base64,$b64";

    final headers = <String, String>{
      "Accept": "application/json",
      "Content-Type": "application/json",
    };
    if (token != null)
      headers[HttpHeaders.authorizationHeader] = 'Bearer $token';

    final body = jsonEncode({"profile_photo": payload});

    http.Response resp;
    resp = await http.put(uri, headers: headers, body: body);
    // if (usePut) {
    // } else {
    //   resp = await http.post(uri, headers: headers, body: body);
    // }

    print("DEBUG PUT PHOTO => ${resp.statusCode}");
    print("BODY => ${resp.body}");

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      try {
        final parsed = jsonDecode(resp.body) as Map<String, dynamic>;
        if (parsed['data'] != null && parsed['data'] is Map) {
          // data mungkin berisi hanya profile_photo (url) atau lebih
          final Map<String, dynamic> dataMap = Map<String, dynamic>.from(
            parsed['data'] as Map,
          );
          await PreferenceHandler.saveProfile(dataMap);
        }
      } catch (e) {
        print("WARN: gagal parse saveProfile after photo upload: $e");
      }
      return true;
    } else {
      // lempar pesan error agar UI bisa menampilkan
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> getTrainings() async {
    final uri = Uri.parse(
      '$baseUrl/api/trainings',
    ); // ganti path jika endpoint berbeda
    final resp = await http.get(uri, headers: {"Accept": "application/json"});

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      if (body is Map && body['data'] is List) {
        final list = List<Map<String, dynamic>>.from(
          (body['data'] as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        return list;
      }
      return [];
    } else {
      throw Exception('Gagal ambil daftar training (HTTP ${resp.statusCode})');
    }
  }

  static Future<List<Map<String, dynamic>>> getTraining() async {
    final resp = await http.get(Uri.parse('$baseUrl/api/trainings'));
    if (resp.statusCode == 200) {
      final parsed = jsonDecode(resp.body);
      final list = (parsed['data'] as List).cast<Map<String, dynamic>>();
      return list;
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getBatches() async {
    final resp = await http.get(Uri.parse('$baseUrl/api/batches'));
    if (resp.statusCode == 200) {
      final parsed = jsonDecode(resp.body);
      final list = (parsed['data'] as List).cast<Map<String, dynamic>>();
      return list;
    }
    return [];
  }
}
