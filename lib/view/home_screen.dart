import 'dart:io';
import 'package:absensi_san/models/attendance_statistics.dart';
import 'package:absensi_san/models/attendance_today.dart';
import 'package:absensi_san/service/api.dart';
import 'package:absensi_san/view/map_screen.dart'; // <-- import map screen
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AttendanceToday? today;
  AttendanceStatistics? stat;
  bool isLoadingPage = false;
  bool isSubmitting = false;
  String userName = "User";

  // lokasi terakhir dari Geolocator
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    loadUserProfile();
    loadDashboard();
  }

  Future<void> loadUserProfile() async {
    try {
      final profile = await AuthAPI.getProfile();
      if (!mounted) return;
      setState(() => userName = profile.name ?? "User");
    } catch (e) {
      if (!mounted) return;
      setState(() => userName = "User");
    }
  }

  Future<void> loadDashboard() async {
    setState(() => isLoadingPage = true);
    try {
      final todayData = await AuthAPI.getToday();
      final statData = await AuthAPI.getStatistik();

      if (!mounted) return;
      setState(() {
        today = todayData;
        stat = statData;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal memuat dashboard: $e")));
    } finally {
      if (!mounted) return;
      setState(() => isLoadingPage = false);
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'Layanan lokasi tidak aktif';

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Izin lokasi ditolak';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Izin lokasi ditolak permanen';
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> handleAttendance() async {
    if (isSubmitting || !mounted) return;
    setState(() => isSubmitting = true);

    try {
      final pos = await _determinePosition();
      const address = "Jakarta";

      // simpan lokasi terakhir buat ditampilkan + buka map
      setState(() {
        _lastPosition = pos;
      });

      // ============= CHECK IN =============
      if (today?.checkInTime == null) {
        final success = await AuthAPI.absenCheckIn(
          lat: pos.latitude,
          lng: pos.longitude,
          address: address,
        );

        if (success && mounted) {
          setState(() {
            today = AttendanceToday(
              attendanceDate: DateFormat("yyyy-MM-dd").format(DateTime.now()),
              checkInTime: DateFormat("HH:mm").format(DateTime.now()),
              status: "masuk",
              checkInAddress: address,
            );
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Berhasil Check In")));
        }

        // ============= CHECK OUT =============
      } else if (today?.checkOutTime == null) {
        final success = await AuthAPI.absenCheckOut(
          lat: pos.latitude,
          lng: pos.longitude,
          address: address,
        );

        if (success && mounted) {
          setState(() {
            today = AttendanceToday(
              attendanceDate: today?.attendanceDate,
              checkInTime: today?.checkInTime,
              checkOutTime: DateFormat("HH:mm").format(DateTime.now()),
              status: today?.status,
              checkInAddress: today?.checkInAddress,
              checkOutAddress: address,
            );
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Berhasil Check Out")));
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Sudah absen hari ini")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal absen: $e")));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Widget statCard(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
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
    // tanggal hari ini
    final now = DateTime.now();
    final todayString = DateFormat("EEEE, dd MMMM yyyy", "id_ID").format(now);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: isLoadingPage
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 10),
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
                          const SizedBox(height: 4),
                          Text(
                            todayString,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ================== ABSEN HARI INI ==================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
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
                                const Text("Jam Masuk"),
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
                            Column(
                              children: [
                                const Text("Jam Pulang"),
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
                          child: Text(
                            today?.status?.toUpperCase() ?? "Belum Absen",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // lokasi terakhir + tombol lihat map
                        if (_lastPosition != null) ...[
                          Text(
                            "Lokasi terakhir: "
                            "${_lastPosition!.latitude.toStringAsFixed(5)}, "
                            "${_lastPosition!.longitude.toStringAsFixed(5)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MapScreen(
                                      latitude: _lastPosition!.latitude,
                                      longitude: _lastPosition!.longitude,
                                      title: "Lokasi Absen Hari Ini",
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map),
                              label: const Text("Lihat di Map"),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // tombol CHECK IN / CHECK OUT
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: today?.checkInTime == null
                          ? Colors.green
                          : (today?.checkOutTime == null
                                ? Colors.orange
                                : Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: (today?.checkOutTime != null || isSubmitting)
                        ? null
                        : handleAttendance,
                    child: Text(
                      today?.checkInTime == null
                          ? "CHECK IN"
                          : (today?.checkOutTime == null
                                ? "CHECK OUT"
                                : "SUDAH ABSEN"),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ================== STATISTIK ABSEN ==================
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
