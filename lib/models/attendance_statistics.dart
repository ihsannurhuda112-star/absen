class AttendanceStatistics {
  final int totalAbsen;
  final int totalMasuk;
  final int totalIzin;
  final bool sudahAbsenHariIni;

  AttendanceStatistics({
    required this.totalAbsen,
    required this.totalMasuk,
    required this.totalIzin,
    required this.sudahAbsenHariIni,
  });

  factory AttendanceStatistics.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return AttendanceStatistics(
      totalAbsen: data['total_absen'] ?? 0,
      totalMasuk: data['total_masuk'] ?? 0,
      totalIzin: data['total_izin'] ?? 0,
      sudahAbsenHariIni: data['sudah_absen_hari_ini'] ?? false,
    );
  }
}
