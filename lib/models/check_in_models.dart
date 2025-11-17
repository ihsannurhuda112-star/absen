class CheckInModels {
  final String attendanceDate;
  final String checkIn;
  final double lat;
  final double lng;
  final String address;
  final String status; // default: "masuk" atau "izin"

  CheckInModels({
    required this.attendanceDate,
    required this.checkIn,
    required this.lat,
    required this.lng,
    required this.address,
    this.status = "masuk",
  });

  Map<String, dynamic> toJson() {
    return {
      "attendance_date": attendanceDate,
      "check_in": checkIn,
      "check_in_lat": lat,
      "check_in_lng": lng,
      "check_in_address": address,
      "status": status,
    };
  }
}
