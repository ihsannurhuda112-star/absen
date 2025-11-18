class AttendanceToday {
  final String? attendanceDate;
  final String? checkInTime;
  final String? checkOutTime;
  final String? checkInAddress;
  final String? checkOutAddress;
  final String? status;
  final String? alasanIzin;

  AttendanceToday({
    this.attendanceDate,
    this.checkInTime,
    this.checkOutTime,
    this.checkInAddress,
    this.checkOutAddress,
    this.status,
    this.alasanIzin,
  });

  factory AttendanceToday.fromJson(Map<String, dynamic> json) {
    return AttendanceToday(
      attendanceDate: json['attendance_date']?.toString(),
      checkInTime: json['check_in']?.toString(), // <- Fix
      checkOutTime: json['check_out']?.toString(), // <- Fix
      checkInAddress: json['check_in_address']?.toString(),
      checkOutAddress: json['check_out_address']?.toString(),
      status: json['status']?.toString(),
      alasanIzin: json['alasan_izin']?.toString(),
    );
  }
}
