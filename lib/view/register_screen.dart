// lib/view/register_screen_clean.dart

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

  List<Map<String, dynamic>> batches = [];
  List<Map<String, dynamic>> trainings = [];

  int? selectedBatchId;
  int? selectedTrainingId;

  @override
  void initState() {
    super.initState();
    _loadLookupData();
  }

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    passwordController.dispose();
    batchController.dispose();
    trainingController.dispose();
    super.dispose();
  }

  Future<void> _loadLookupData() async {
    try {
      final batchList = AuthAPI.getBatches();
      final trainingList = AuthAPI.getTrainings();
      final results = await Future.wait([batchList, trainingList]);

      if (!mounted) return;
      setState(() {
        batches = results[0] as List<Map<String, dynamic>>;
        trainings = results[1] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      debugPrint("Gagal load lookup: $e");
    }
  }

  Future pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        imageFile = File(photo.path);
      });

      final imageBytes = await photo.readAsBytes();
      base64Image = "data:image/png;base64,${base64Encode(imageBytes)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          child: Form(key: _formKey, child: _buildFormContent()),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Text(
          "Create Account",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        buildLabel("Email"),
        buildTextField(
          controller: emailController,
          hint: "Enter email",
          validator: (v) {
            if (v == null || v.isEmpty) return "Email wajib diisi";
            if (!v.contains("@")) return "Email tidak valid";
            return null;
          },
        ),
        const SizedBox(height: 16),

        buildLabel("Password"),
        buildTextField(
          controller: passwordController,
          hint: "Enter password",
          isPassword: true,
          validator: (v) {
            if (v == null || v.length < 6) return "Minimal 6 karakter";
            return null;
          },
        ),
        const SizedBox(height: 16),

        buildLabel("Nama Lengkap"),
        buildTextField(
          controller: nameController,
          hint: "Enter your name",
          validator: (v) =>
              (v == null || v.isEmpty) ? "Nama wajib diisi" : null,
        ),
        const SizedBox(height: 16),

        buildLabel("Jenis Kelamin"),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: genderValue,
          items: const [
            DropdownMenuItem(value: "L", child: Text("Laki-laki")),
            DropdownMenuItem(value: "P", child: Text("Perempuan")),
          ],
          onChanged: (v) => setState(() => genderValue = v),
          validator: (v) => v == null ? "Pilih jenis kelamin" : null,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(height: 16),

        buildLabel("Profile Photo"),
        GestureDetector(
          onTap: pickImage,
          child: Container(
            height: 120,
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
                ? const Center(child: Text("Tap to upload photo"))
                : null,
          ),
        ),
        const SizedBox(height: 16),

        // ==========================
        // BATCH — sudah tanpa tanggal
        // ==========================
        buildLabel("Batch"),
        batches.isNotEmpty
            ? DropdownButtonFormField<int>(
                isExpanded: true,
                value: selectedBatchId,
                items: batches
                    .map(
                      (b) => DropdownMenuItem<int>(
                        value: int.parse(b['id'].toString()),
                        child: Text(_batchTitle(b)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedBatchId = v),
                validator: (v) => v == null ? "Pilih batch" : null,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              )
            : buildTextField(
                controller: batchController,
                hint: "Contoh: 1",
                validator: (v) =>
                    (v == null || v.isEmpty) ? "Batch ID wajib diisi" : null,
              ),
        const SizedBox(height: 16),

        buildLabel("Training"),
        trainings.isNotEmpty
            ? DropdownButtonFormField<int>(
                isExpanded: true,
                value: selectedTrainingId,
                items: trainings
                    .map(
                      (t) => DropdownMenuItem<int>(
                        value: int.parse(t['id'].toString()),
                        child: Text(t['title']?.toString() ?? 'Untitled'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedTrainingId = v),
                validator: (v) => v == null ? "Pilih training" : null,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              )
            : buildTextField(
                controller: trainingController,
                hint: "Masukkan ID training (contoh: 1)",
                validator: (v) =>
                    (v == null || v.isEmpty) ? "Training ID wajib diisi" : null,
              ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: isLoading ? null : register,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Register"),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Have an account?"),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreenSan()),
                );
              },
              child: const Text(
                "Login",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ================================
  // FIXED: batch title tanpa tanggal
  // ================================
  String _batchTitle(Map<String, dynamic> b) {
    final String batchKe = b['batch_ke']?.toString() ?? '';
    if (batchKe.isNotEmpty) return "Batch $batchKe";

    final String idStr = b['id']?.toString() ?? '';
    return "Batch $idStr";
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

    if (base64Image.isEmpty) {
      Fluttertoast.showToast(msg: "Foto wajib diupload");
      return;
    }

    if (genderValue == null) {
      Fluttertoast.showToast(msg: "Pilih jenis kelamin");
      return;
    }

    int batchId;
    if (selectedBatchId != null) {
      batchId = selectedBatchId!;
    } else {
      batchId = int.parse(batchController.text.trim());
    }

    int trainingId;
    if (selectedTrainingId != null) {
      trainingId = selectedTrainingId!;
    } else {
      trainingId = int.parse(trainingController.text.trim());
    }

    setState(() => isLoading = true);

    try {
      final result = await AuthAPI.registerUser(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        jenisKelamin: genderValue!,
        profilePhoto: base64Image,
        batchId: batchId,
        trainingId: trainingId,
      );

      await PreferenceHandler.saveToken(result.data?.token ?? "");
      if (result.data?.user?.name != null)
        await PreferenceHandler.saveUserName(result.data!.user!.name!);

      Fluttertoast.showToast(msg: "Registrasi berhasil!");
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreenSan()),
        );
      });
    } catch (e) {
      String msg = e.toString();
      try {
        if (msg.contains('{') && msg.contains('}')) {
          final start = msg.indexOf('{');
          final jsonStr = msg.substring(start);
          final parsed = jsonDecode(jsonStr);
          if (parsed is Map && parsed['message'] != null)
            msg = parsed['message'].toString();
        }
      } catch (_) {}
      Fluttertoast.showToast(msg: "Error: $msg");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget buildLabel(String text) => Row(
    children: [
      Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
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
