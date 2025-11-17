class ProfileModel {
  String? message;
  ProfileData? data;

  ProfileModel({this.message, this.data});

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      message: json['message'],
      data: json['data'] != null ? ProfileData.fromJson(json['data']) : null,
    );
  }
}

class ProfileData {
  int? id;
  String? name;
  String? email;

  ProfileData({this.id, this.name, this.email});

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}
