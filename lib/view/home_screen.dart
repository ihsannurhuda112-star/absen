import 'dart:convert';
import 'dart:io';
import 'package:absensi_san/models/attendance_statistics.dart';
import 'package:absensi_san/models/attendance_today.dart';
import 'package:absensi_san/service/api.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AttendanceToday? today;
  AttendanceStatistics? stat;
  bool isLoading = false;
  String userName = "User";

  @override
  void initState() {
    super.initState();
    loadUserProfile();
    loadDashboard();
  }

  // Ambil username
  Future<void> loadUserProfile() async {
    try {
      final profile = await AuthAPI.getProfile();
      setState(() {
        userName = profile.name ?? "User";
      });
    } catch (e) {
      setState(() => userName = "User");
    }
  }

  // Load dashboard
  Future<void> loadDashboard() async {
    setState(() => isLoading = true);
    try {
      final todayData = await AuthAPI.getToday();
      final statData =
          await AuthAPI.getStatistik(); // <--- pakai versi tanpa parameter

      setState(() {
        today = todayData;
        stat = statData;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal memuat dashboard: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Cek & minta izin lokasi
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'Layanan lokasi tidak aktif';

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw 'Izin lokasi ditolak';
    }
    if (permission == LocationPermission.deniedForever)
      throw 'Izin lokasi ditolak permanen';

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Handle Check In / Check Out
  Future<void> handleAttendance() async {
    try {
      setState(() => isLoading = true);
      Position position = await _determinePosition();
      String address = "Jakarta";

      if (today?.checkInTime == null) {
        final success = await AuthAPI.absenCheckIn(
          lat: position.latitude,
          lng: position.longitude,
          address: address,
        );
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Berhasil Check In")));
        }
      } else if (today?.checkOutTime == null) {
        final success = await AuthAPI.absenCheckOut(
          lat: position.latitude,
          lng: position.longitude,
          address: address,
        );
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Berhasil Check Out")));
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Sudah absen hari ini")));
      }

      await loadDashboard();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal absen: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Widget statistik card
  Widget statCard(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [
          Text(
            "$value",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 10),
                  // Greeting
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 32,
                        child: Icon(Icons.person, size: 38),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hai, $userName",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Selamat bekerja ✨",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Absen Hari Ini
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 8),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.access_time, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              "Absen Hari Ini",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  "Jam Masuk",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  today?.checkInTime ?? "-",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            Column(
                              children: [
                                Text(
                                  "Jam Pulang",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  today?.checkOutTime ?? "-",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  today?.status?.toUpperCase() ?? "Belum Absen",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Tombol Check In / Out
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: today?.checkInTime == null
                          ? Colors.green
                          : Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: handleAttendance,
                    child: Text(
                      today?.checkInTime == null
                          ? "CHECK IN"
                          : today?.checkOutTime == null
                          ? "CHECK OUT"
                          : "SUDAH ABSEN",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Statistik Kehadiran
                  const Text(
                    "Statistik Kehadiran",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: statCard(
                          "Hadir",
                          stat?.totalMasuk ?? 0,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: statCard(
                          "Izin",
                          stat?.totalIzin ?? 0,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: statCard(
                          "Alpha",
                          (stat?.totalAbsen ?? 0) -
                              ((stat?.totalMasuk ?? 0) +
                                  (stat?.totalIzin ?? 0)),
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: statCard(
                          "Total Absen",
                          stat?.totalAbsen ?? 0,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
