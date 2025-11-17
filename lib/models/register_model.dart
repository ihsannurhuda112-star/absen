class RegisterModel {
  String? message;
  RegisterData? data;

  RegisterModel({this.message, this.data});

  RegisterModel.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    data = json['data'] != null ? RegisterData.fromJson(json['data']) : null;
  }
}

class RegisterData {
  String? token;
  RegisterUser? user;

  RegisterData({this.token, this.user});

  RegisterData.fromJson(Map<String, dynamic> json) {
    token = json['token'];
    user = json['user'] != null ? RegisterUser.fromJson(json['user']) : null;
  }
}

class RegisterUser {
  int? id;
  String? name;
  String? email;
  String? jenisKelamin;
  String? profilePhoto;
  int? batchId;
  int? trainingId;

  RegisterUser({
    this.id,
    this.name,
    this.email,
    this.jenisKelamin,
    this.profilePhoto,
    this.batchId,
    this.trainingId,
  });

  RegisterUser.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    email = json['email'];
    jenisKelamin = json['jenis_kelamin'];
    profilePhoto = json['profile_photo'];
    batchId = json['batch_id'];
    trainingId = json['training_id'];
  }
}
