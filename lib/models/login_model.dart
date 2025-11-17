class LoginModel {
  String? message;
  LoginData? data;

  LoginModel({this.message, this.data});

  factory LoginModel.fromJson(Map<String, dynamic> json) => LoginModel(
    message: json["message"],
    data: json["data"] != null ? LoginData.fromJson(json["data"]) : null,
  );
}

class LoginData {
  String? token;
  User? user;

  LoginData({this.token, this.user});

  factory LoginData.fromJson(Map<String, dynamic> json) => LoginData(
    token: json["token"],
    user: json["user"] != null ? User.fromJson(json["user"]) : null,
  );
}

class User {
  int? id;
  String? name;
  String? email;

  User({this.id, this.name, this.email});

  factory User.fromJson(Map<String, dynamic> json) =>
      User(id: json["id"], name: json["name"], email: json["email"]);
}
