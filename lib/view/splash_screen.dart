import 'package:flutter/material.dart';
import 'package:absensi_san/preference/preference_handler.dart';
import 'package:absensi_san/service/api.dart';
import 'package:absensi_san/navigation/buttom_navigator.dart';
import 'package:absensi_san/view/login_screen.dart';

class SplashScreenSan extends StatefulWidget {
  const SplashScreenSan({super.key});

  @override
  State<SplashScreenSan> createState() => _SplashScreenSanState();
}

class _SplashScreenSanState extends State<SplashScreenSan>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // ANIMASI LOGO
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Setelah animasi berjalan → check login
    Future.delayed(const Duration(milliseconds: 1500), _checkLogin);
  }

  Future<void> _checkLogin() async {
    final token = await PreferenceHandler.getToken();

    if (token != null && token.isNotEmpty) {
      bool valid = true;
      try {
        await AuthAPI.getProfile();
      } catch (_) {
        valid = false;
      }

      if (valid && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ButtomNavigator()),
        );
        return;
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreenSan()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8EA5FF), Color(0xFFC6D9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  height: 110,
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.access_time_filled_rounded,
                    size: 60,
                    color: Color(0xFF4A65E8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 26),

            FadeTransition(
              opacity: _fadeAnim,
              child: const Text(
                "AbsenS",
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 10),

            FadeTransition(
              opacity: _fadeAnim,
              child: const Text(
                "Mengelola Kehadiran Lebih Mudah",
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ),

            const SizedBox(height: 50),

            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
