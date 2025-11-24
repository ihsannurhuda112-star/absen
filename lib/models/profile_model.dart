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
  String? profilePhoto;

  ProfileData({this.id, this.name, this.email, this.profilePhoto});

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      profilePhoto: json['profile_photo'] ?? json['profilePhoto'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profile_photo': profilePhoto,
    };
  }
}
