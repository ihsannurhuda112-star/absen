import 'package:absensi_san/service/api.dart';
import 'package:absensi_san/view/verify_otp_screen.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  Future<void> sendOtp() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Email tidak boleh kosong")));
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await AuthAPI.requestResetPassword(email: email);

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP berhasil dikirim ke email")),
        );

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VerifyOtpScreen(email: email)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          buildBackground(), // <-- Tambahkan background
          buildLayer(), // <-- UI utama
        ],
      ),
    );
  }

  // ==========================
  // BACKGROUND
  // ==========================
  Widget buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/kertas.png"),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // ==========================
  // UI LAYER
  // ==========================
  Widget buildLayer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  "Forgot Password",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                const Text(
                  "Masukkan email kamu untuk menerima kode OTP reset password.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : sendOtp,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Kirim OTP"),
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Kembali ke Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
