import 'package:absensi_san/service/api.dart';
import 'package:absensi_san/view/success_reset_screen.dart';
import 'package:flutter/material.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final otpController = TextEditingController();
  final passController = TextEditingController();
  bool isLoading = false;
  bool showPass = false;

  Future<void> verifyAndReset() async {
    final otp = otpController.text.trim();
    final password = passController.text.trim();

    if (otp.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OTP dan password wajib diisi")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password minimal 6 karakter")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await AuthAPI.verifyOtpAndResetPassword(
        email: widget.email,
        otp: otp,
        newPassword: password,
      );

      if (result) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SuccessResetScreen()),
          (route) => false,
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
    return Scaffold(body: Stack(children: [buildBackground(), buildLayer()]));
  }

  // =======================
  // BACKGROUND
  // =======================
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

  // =======================
  // UI LAYER
  // =======================
  Widget buildLayer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- TITLE ----------
                const Text(
                  "Verify OTP",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                Text(
                  "Email: ${widget.email}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 20),

                // ---------- INPUT OTP ----------
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Masukkan OTP",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // ---------- NEW PASSWORD ----------
                TextField(
                  controller: passController,
                  obscureText: !showPass,
                  decoration: InputDecoration(
                    labelText: "Password Baru",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPass ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => showPass = !showPass);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ---------- BUTTON ----------
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : verifyAndReset,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Reset Password"),
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Kembali"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
