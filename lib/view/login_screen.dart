// lib/view/login_screen_san.dart
import 'package:absensi_san/navigation/buttom_navigator.dart';
import 'package:absensi_san/preference/preference_handler.dart';
import 'package:absensi_san/view/forgot_password_screen.dart';
import 'package:absensi_san/view/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:absensi_san/service/api.dart';
import 'package:absensi_san/models/login_model.dart';
import 'package:intl/intl.dart';

class LoginScreenSan extends StatefulWidget {
  const LoginScreenSan({super.key});

  @override
  State<LoginScreenSan> createState() => _LoginScreenSanState();
}

class _LoginScreenSanState extends State<LoginScreenSan> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isVisibility = false;
  bool isLoading = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Stack(children: [buildBackground(), buildLayer()]));
  }

  // ================================
  //             UI LAYER
  // ================================
  SafeArea buildLayer() {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Text(
                    "Welcome Back",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text("Login to access your account"),
                  const SizedBox(height: 24),

                  // ---------------- EMAIL ----------------
                  buildTextField(
                    hintText: "Enter your email",
                    controller: emailController,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return "Email tidak boleh kosong";
                      }
                      if (!v.contains("@")) {
                        return "Email tidak valid";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // ---------------- PASSWORD ----------------
                  buildTextField(
                    hintText: "Enter your password",
                    controller: passwordController,
                    isPassword: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return "Password tidak boleh kosong";
                      }
                      if (v.length < 6) {
                        return "Password minimal 6 karakter";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // ---------------- LOGIN BUTTON ----------------
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : login,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Login"),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---------------- FOOTER REGISTER ----------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegisterScreenClean(),
                            ),
                          );
                        },
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================================
  //             LOGIN LOGIC
  // ================================
  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // 1) Authenticate
      final result = await AuthAPI.loginUser(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // if login success and server returned token -> save token
      if (result.data != null && result.data!.token != null) {
        await PreferenceHandler.saveToken(result.data!.token!);
      }

      // 2) Fetch profile (authoritative) and save userId + username if available
      try {
        final profile = await AuthAPI.getProfile();

        // NOTE: replace `profile.id` if your ProfileModel uses different field name
        if (profile.id != null) {
          await PreferenceHandler.saveUserId(profile.id.toString());
        }

        if (profile.name != null && profile.name!.isNotEmpty) {
          await PreferenceHandler.saveUserName(profile.name!);
        }
      } catch (e) {
        // non-blocking: gagal ambil profil tidak menghalangi login
        debugPrint('Warn: failed to fetch profile after login: $e');
      }

      // 3) Sinkronisasi statistik hari ini (non-blocking)
      try {
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final statsToday = await AuthAPI.getStatistik(
          start: todayStr,
          end: todayStr,
        );

        // simpan boolean sudahAbsen hari ini (per-user via PreferenceHandler)
        await PreferenceHandler.saveAbsenStatusToday(
          statsToday.sudahAbsenHariIni,
        );

        // jika API punya today object, ambil juga dan simpan object ke cache per-user
        final todayData = await AuthAPI.getToday();
        if (todayData != null) {
          await PreferenceHandler.saveTodayAttendance(todayData.toJson());
        }
      } catch (e) {
        debugPrint('Warn: failed to sync today stats after login: $e');
      }

      Fluttertoast.showToast(msg: "Login berhasil");

      // 4) Navigate to main app
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ButtomNavigator()),
      );
    } catch (e) {
      // tampilkan error login
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================================
  //          WIDGET FIELD
  // ================================
  TextFormField buildTextField({
    required String hintText,
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: isPassword ? !isVisibility : false,
      decoration: InputDecoration(
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isVisibility ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => isVisibility = !isVisibility);
                },
              )
            : null,
      ),
    );
  }

  // ================================
  //           BACKGROUND
  // ================================
  Container buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/kertas.png"),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
