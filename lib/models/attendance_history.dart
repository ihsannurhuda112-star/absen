import 'package:flutter/foundation.dart';

class AttendanceHistory {
  final int id;
  final DateTime attendanceDate; // yyyy-MM-dd
  final String? checkInTime; // "HH:mm" or null
  final String? checkOutTime; // "HH:mm" or null
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;
  final String? checkInAddress;
  final String? checkOutAddress;
  final String? checkInLocation; // fallback string "lat,lng"
  final String? checkOutLocation;
  final String status; // "masuk" / "izin"
  final String? alasanIzin;

  AttendanceHistory({
    required this.id,
    required this.attendanceDate,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
    this.checkInAddress,
    this.checkOutAddress,
    this.checkInLocation,
    this.checkOutLocation,
    required this.status,
    this.alasanIzin,
  });

  factory AttendanceHistory.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String s) => DateTime.parse(s); // "2025-07-09"
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return AttendanceHistory(
      id: json['id'] as int,
      attendanceDate: parseDate(json['attendance_date'] as String),
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      checkInLat: toDouble(json['check_in_lat']),
      checkInLng: toDouble(json['check_in_lng']),
      checkOutLat: toDouble(json['check_out_lat']),
      checkOutLng: toDouble(json['check_out_lng']),
      checkInAddress: json['check_in_address'] as String?,
      checkOutAddress: json['check_out_address'] as String?,
      checkInLocation: json['check_in_location'] as String?,
      checkOutLocation: json['check_out_location'] as String?,
      status: (json['status'] as String?) ?? '-',
      alasanIzin: json['alasan_izin'] as String?,
    );
  }
}
