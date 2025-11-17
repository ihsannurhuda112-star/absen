import 'package:absensi_san/preference/preference_handler.dart';
import 'package:absensi_san/view/forgot_password_screen.dart';
import 'package:absensi_san/view/home_screen.dart';
import 'package:absensi_san/view/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:absensi_san/service/api.dart';
import 'package:absensi_san/models/login_model.dart';

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
                  Text(
                    "Welcome Back",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text("Login to access your account"),
                  SizedBox(height: 24),

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

                  SizedBox(height: 16),

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

                  SizedBox(height: 24),

                  // ---------------- LOGIN BUTTON ----------------
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : login,
                      child: isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text("Login"),
                    ),
                  ),

                  SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // ---------------- FOOTER REGISTER ----------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegisterScreenClean(),
                            ),
                          );
                        },
                        child: Text(
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
      final result = await AuthAPI.loginUser(
        email: emailController.text,
        password: passwordController.text,
      );

      // simpan token
      await PreferenceHandler.saveToken(result.data!.token!);
      final profile = await AuthAPI.getProfile();
      if (profile.name != null) {
        await PreferenceHandler.saveUserName(profile.name!);
      }

      Fluttertoast.showToast(msg: "Login berhasil");

      // pindah ke home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }

    setState(() => isLoading = false);
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
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/kertas.png"),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
