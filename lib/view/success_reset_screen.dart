import 'package:flutter/material.dart';
import 'package:absensi_san/view/login_screen.dart';

class SuccessResetScreen extends StatelessWidget {
  const SuccessResetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 120),
              const SizedBox(height: 20),
              const Text(
                "Password berhasil direset!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "Silakan login menggunakan password baru kamu.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreenSan()),
                      (route) => false,
                    );
                  },
                  child: const Text("Kembali ke Login"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
