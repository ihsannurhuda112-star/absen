class Endpoint {
  static const String baseUrl = "https://appabsensi.mobileprojp.com";

  // auth
  static const String register = "$baseUrl/api/register";
  static const String login = "$baseUrl/api/login";
  static const String forgotPassword = "$baseUrl/api/forgot-password";
  static const String verifyOtp = "$baseUrl/api/reset-password";

  // profile
  static const String profile = "$baseUrl/api/profile";
  static const String editProfile = "$baseUrl/api/edit-profile"; // PUT
  static const String profilePhoto =
      "$baseUrl/api/profile/photo"; // multipart upload (POST)

  // absen
  static const String absenCheckIn = "$baseUrl/api/absen/check-in";
  static const String absenCheckOut = "$baseUrl/api/absen/check-out";
  static const String absenStats = "$baseUrl/api/absen/stats";
  static const String absenHistory = "$baseUrl/api/absen/history";

  static const String izin = "$baseUrl/api/izin";
}
