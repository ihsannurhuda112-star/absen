import 'dart:convert';
import 'package:absensi_san/models/attendance_statistics.dart';
import 'package:absensi_san/models/attendance_today.dart';
import 'package:absensi_san/models/profile_model.dart';
import 'package:absensi_san/models/register_model.dart';
import 'package:absensi_san/models/login_model.dart';
import 'package:absensi_san/preference/preference_handler.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:io';

class AuthAPI {
  static String baseUrl = "https://appabsensi.mobileprojp.com";

  // ============================
  //        REGISTER USER
  // ============================
  static Future<RegisterModel> registerUser({
    required String name,
    required String email,
    required String password,
    required String jenisKelamin,
    required String profilePhoto,
    required int batchId,
    required int trainingId,
  }) async {
    final url = Uri.parse("$baseUrl/api/register");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
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

    if (response.statusCode == 200 || response.statusCode == 201) {
      return RegisterModel.fromJson(json.decode(response.body));
    } else {
      throw Exception("Register gagal: ${response.body}");
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

  static Future<bool> absenCheckIn({
    required double lat,
    required double lng,
    required String address,
  }) async {
    final now = DateTime.now();

    final body = {
      "attendance_date": DateFormat("yyyy-MM-dd").format(now),
      "check_in": DateFormat("HH:mm").format(now),
      "check_in_lat": lat,
      "check_in_lng": lng,
      "check_in_address": address,
      "status": "masuk",
    };

    final response = await http.post(
      Uri.parse("$baseUrl/api/absen-check-in"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    return response.statusCode == 200;
  }

  static Future<bool> absenCheckOut({
    required double lat,
    required double lng,
    required String address,
  }) async {
    final now = DateTime.now();

    final body = {
      "attendance_date": DateFormat("yyyy-MM-dd").format(now),
      "check_out": DateFormat("HH:mm").format(now),
      "check_out_lat": lat,
      "check_out_lng": lng,
      "check_out_location": "$lat, $lng",
      "check_out_address": address,
    };

    final response = await http.post(
      Uri.parse("$baseUrl/api/absen-check-out"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    return response.statusCode == 200;
  }

  static Future<AttendanceToday> getToday() async {
    final now = DateTime.now();
    final todayStr = DateFormat("yyyy-MM-dd").format(now);

    final url = Uri.parse(
      "$baseUrl/api/absen/stats?start=$todayStr&end=$todayStr",
    );
    final token = await PreferenceHandler.getToken();

    final response = await http.get(
      url,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        "Accept": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      // Cek tipe data
      if (body['data'] is List && body['data'].isNotEmpty) {
        return AttendanceToday.fromJson(body['data'][0]);
      } else {
        // belum absen hari ini
        return AttendanceToday();
      }
    } else {
      print("Response body: ${response.body}");
      throw Exception("Gagal ambil absen hari ini");
    }
  }

  static Future<AttendanceStatistics> getStatistik() async {
    final now = DateTime.now();
    final todayStr = DateFormat("yyyy-MM-dd").format(now);

    final url = Uri.parse(
      "$baseUrl/api/absen/stats?start=$todayStr&end=$todayStr",
    );
    final token = await PreferenceHandler.getToken();

    final response = await http.get(
      url,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        "Accept": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = body['data'] ?? {};

      return AttendanceStatistics(
        totalAbsen: data['total_absen'] ?? 0,
        totalMasuk: data['total_masuk'] ?? 0,
        totalIzin: data['total_izin'] ?? 0,
        sudahAbsenHariIni: data['sudah_absen_hari_ini'] ?? false,
      );
    } else {
      print("Response statistik: ${response.body}");
      throw Exception("Gagal ambil statistik absen hari ini");
    }
  }

  static Future<ProfileData> getProfile() async {
    final token = await PreferenceHandler.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/profile'),
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ProfileModel.fromJson(data).data!;
    } else {
      throw Exception('Gagal mengambil profil');
    }
  }
}
