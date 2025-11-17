class CheckOutModel {
  final String attendanceDate;
  final String checkOut;
  final double lat;
  final double lng;
  final String address;

  CheckOutModel({
    required this.attendanceDate,
    required this.checkOut,
    required this.lat,
    required this.lng,
    required this.address,
  });

  Map<String, dynamic> toJson() {
    return {
      "attendance_date": attendanceDate,
      "check_out": checkOut,
      "check_out_lat": lat,
      "check_out_lng": lng,
      "check_out_location": "$lat, $lng",
      "check_out_address": address,
    };
  }
}
