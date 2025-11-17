import 'dart:convert';
import 'dart:io';
import 'package:absensi_san/preference/preference_handler.dart';
import 'package:absensi_san/service/api.dart';
import 'package:absensi_san/models/register_model.dart';
import 'package:absensi_san/view/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

class RegisterScreenClean extends StatefulWidget {
  const RegisterScreenClean({super.key});

  @override
  State<RegisterScreenClean> createState() => _RegisterScreenCleanState();
}

class _RegisterScreenCleanState extends State<RegisterScreenClean> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  final batchController = TextEditingController();
  final trainingController = TextEditingController();
  String? genderValue;

  bool isLoading = false;
  bool isHidePassword = true;

  File? imageFile;
  String base64Image = "";

  Future pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);

    if (photo != null) {
      setState(() {
        imageFile = File(photo.path);
      });

      List<int> imageBytes = await photo.readAsBytes();
      base64Image = "data:image/png;base64,${base64Encode(imageBytes)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [buildBackground(), buildFormLayer()]),
    );
  }

  Widget buildFormLayer() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                "Create Account",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),

              // EMAIL
              buildLabel("Email"),
              buildTextField(
                controller: emailController,
                hint: "Enter email",
                validator: (v) {
                  if (v!.isEmpty) return "Email wajib diisi";
                  if (!v.contains("@")) return "Email tidak valid";
                  return null;
                },
              ),
              SizedBox(height: 16),

              // PASSWORD
              buildLabel("Password"),
              buildTextField(
                controller: passwordController,
                hint: "Enter password",
                isPassword: true,
                validator: (v) => v!.length < 6 ? "Minimal 6 karakter" : null,
              ),
              SizedBox(height: 16),

              // NAME
              buildLabel("Nama Lengkap"),
              buildTextField(
                controller: nameController,
                hint: "Enter your name",
                validator: (v) => v!.isEmpty ? "Nama wajib diisi" : null,
              ),
              SizedBox(height: 16),

              // JENIS KELAMIN
              buildLabel("Jenis Kelamin"),
              DropdownButtonFormField(
                value: genderValue,
                items: [
                  DropdownMenuItem(value: "L", child: Text("Laki-laki")),
                  DropdownMenuItem(value: "P", child: Text("Perempuan")),
                ],
                onChanged: (v) => setState(() => genderValue = v),
                validator: (v) => v == null ? "Pilih jenis kelamin" : null,
              ),
              SizedBox(height: 16),

              // FOTO
              buildLabel("Profile Photo"),
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                    image: imageFile != null
                        ? DecorationImage(
                            image: FileImage(imageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageFile == null
                      ? Center(child: Text("Tap to upload photo"))
                      : null,
                ),
              ),
              SizedBox(height: 16),

              // BATCH ID
              buildLabel("Batch ID"),
              buildTextField(
                controller: batchController,
                hint: "Contoh: 1",
                validator: (v) => v!.isEmpty ? "Batch ID wajib diisi" : null,
              ),
              SizedBox(height: 16),

              // TRAINING ID
              buildLabel("Training ID"),
              buildTextField(
                controller: trainingController,
                hint: "Contoh: 1",
                validator: (v) => v!.isEmpty ? "Training ID wajib diisi" : null,
              ),
              SizedBox(height: 24),

              // BUTTON REGISTER
              ElevatedButton(
                onPressed: isLoading ? null : register,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Register"),
              ),
              SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => LoginScreenSan()),
                      );
                    },
                    child: Text(
                      "Login",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;
    if (base64Image.isEmpty) {
      Fluttertoast.showToast(msg: "Foto wajib diupload");
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await AuthAPI.registerUser(
        name: nameController.text,
        email: emailController.text,
        password: passwordController.text,
        jenisKelamin: genderValue!,
        profilePhoto: base64Image,
        batchId: int.parse(batchController.text),
        trainingId: int.parse(trainingController.text),
      );

      // ==============================
      // ✅ SIMPAN TOKEN LOGIN
      // ==============================
      await PreferenceHandler.saveToken(result.data?.token ?? "");

      if (result.data!.user != null && result.data!.user!.name != null) {
        await PreferenceHandler.saveUserName(result.data!.user!.name!);
      }

      Fluttertoast.showToast(msg: "Registrasi berhasil!");

      // ==============================
      //  Redirect ke Login
      // ==============================
      Future.delayed(Duration(milliseconds: 500), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreenSan()),
        );
      });
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    }

    setState(() => isLoading = false);
  }

  Widget buildBackground() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/kertas.png"),
          opacity: 2,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget buildLabel(String text) => Row(
    children: [
      Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ],
  );

  Widget buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: isPassword ? isHidePassword : false,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isHidePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => isHidePassword = !isHidePassword),
              )
            : null,
      ),
    );
  }
}
