// lib/view/profile_screen.dart

import 'dart:io';
import 'dart:convert';

import 'package:absensi_san/preference/preference_handler.dart';
import 'package:absensi_san/service/api.dart';
import 'package:absensi_san/models/profile_model.dart';
import 'package:absensi_san/view/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _loggingOut = false;
  ProfileData? _profile;
  File? _pickedImage;

  // url/path foto profil (diambil dari cache / response backend)
  String? _profilePhoto;

  // controllers for edit form
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFromCacheThenServer();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  /// Load cached profile first -> then sync from server.
  /// Selain set _profile, juga set _profilePhoto dari cached map jika ada.
  Future<void> _loadFromCacheThenServer() async {
    if (mounted) setState(() => _loading = true);

    // 1) try load cached profile
    try {
      final Map<String, dynamic>? cached =
          await PreferenceHandler.getSavedProfile();
      if (cached != null) {
        final p = ProfileModel.fromJson({'data': cached}).data;
        if (p != null && mounted) {
          setState(() {
            _profile = p;
            _nameCtrl.text = p.name ?? '';
            _emailCtrl.text = p.email ?? '';
          });
        }
        // read profile_photo directly from cached map (backend stores key 'profile_photo')
        if (cached['profile_photo'] != null) {
          final raw = cached['profile_photo'].toString();
          if (mounted) setState(() => _profilePhoto = raw);
        }
      }
    } catch (_) {
      // ignore cache errors
    }

    // 2) sync from server (authoritative)
    try {
      final p = await AuthAPI.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _nameCtrl.text = p.name ?? '';
        _emailCtrl.text = p.email ?? '';
      });

      // After AuthAPI.getProfile() the PreferenceHandler.saveProfile should already have been called inside API.
      // Read saved profile from prefs to get latest profile_photo (if backend returned one).
      try {
        final Map<String, dynamic>? fresh =
            await PreferenceHandler.getSavedProfile();
        if (fresh != null && fresh['profile_photo'] != null) {
          final raw = fresh['profile_photo'].toString();
          if (mounted) setState(() => _profilePhoto = raw);
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat profil dari server: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final XFile? img = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (img == null) return;
      if (mounted) setState(() => _pickedImage = File(img.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_pickedImage == null) return;
    if (mounted) setState(() => _saving = true);
    try {
      // Jika backend mendukung multipart (recommended) gunakan editProfilePhoto.
      // Jika kamu pakai base64 endpoint, ubah pemanggilan sesuai implementasimu.
      final ok = await AuthAPI.editProfilePhotoBase64(imageFile: _pickedImage!);

      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload foto profil berhasil')),
          );
        }
        // reload authoritative profile (akan menulis cache)
        await _loadFromCacheThenServer();

        // clear picked image preview
        if (mounted) setState(() => _pickedImage = null);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Upload gagal')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal upload foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfileChanges() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty || email.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama dan email wajib diisi')),
        );
      return;
    }

    if (mounted) setState(() => _saving = true);
    try {
      final ok = await AuthAPI.editProfile(name: name, email: email);
      if (ok) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil berhasil diperbarui')),
          );
        await _loadFromCacheThenServer();
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan profil')),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan profil: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openEditDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Profil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),

              // kamu bisa mengaktifkan email edit jika backend izinkan
              // TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveProfileChanges();
              },
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  /// show confirmation then logout: clear prefs and navigate to login (wipe history)
  Future<void> _confirmLogout() async {
    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Anda yakin ingin logout? Semua data sementara akan dihapus dari perangkat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, // warna tombol
              foregroundColor: Colors.white, // warna teks/icon
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (should == true) {
      await _doLogout();
    }
  }

  Future<void> _doLogout() async {
    if (mounted) setState(() => _loggingOut = true);

    try {
      await PreferenceHandler.clearAllOnLogout();

      // navigate to login and remove all previous routes
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreenSan(),
        ), // sesuaikan nama class jika berbeda
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal logout: $e')));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Widget _buildAvatar() {
    final double radius = 56;

    // 1) picked local image preview
    if (_pickedImage != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(_pickedImage!),
      );
    }

    // 2) profile photo from cached/server
    if (_profilePhoto != null && _profilePhoto!.isNotEmpty) {
      final trimmed = _profilePhoto!.trim();
      String url;
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        url = trimmed;
      } else {
        // backend mungkin mengembalikan '/public/...' atau 'public/...'
        if (trimmed.startsWith('/')) {
          url = '${AuthAPI.baseUrl}/public$trimmed';
        } else {
          url = '${AuthAPI.baseUrl}/public/$trimmed';
        }
      }
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
    }

    // 3) fallback placeholder
    return CircleAvatar(radius: radius, child: Icon(Icons.person, size: 56));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: const Text('Profil Pengguna'),
        actions: [
          // IconButton(
          //   onPressed: _openEditDialog,
          //   icon: const Icon(Icons.edit_outlined),
          //   tooltip: 'Edit Profil',
          // ),
          // IconButton(
          //   onPressed: _loggingOut ? null : _confirmLogout,
          //   icon: _loggingOut
          //       ? const SizedBox(
          //           width: 20,
          //           height: 20,
          //           child: CircularProgressIndicator(strokeWidth: 2),
          //         )
          //       : const Icon(Icons.logout_outlined),
          //   tooltip: 'Logout',
          // ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFromCacheThenServer,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                children: [
                  // Profile header card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFDF7FF), Color(0xFFF3F7FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // avatar + name/email
                        Row(
                          children: [
                            // decorative ring around avatar
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8B6CFF),
                                    Color(0xFFCFB8FF),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: _buildAvatar(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _profile?.name ?? '-',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.email_outlined,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _profile?.email ?? '-',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'ID: ${_profile?.id ?? "-"}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // action row: pick/upload/refresh
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Pilih Foto'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: _pickedImage != null && !_saving
                                  ? _uploadImage
                                  : null,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Upload'),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () async {
                                await _loadFromCacheThenServer();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Di-refresh')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'Refresh',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Details list (modern tiles)
                  Material(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    elevation: 1,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: const Text('Nama'),
                          subtitle: Text(_profile?.name ?? '-'),
                          trailing: IconButton(
                            onPressed: _openEditDialog,
                            icon: const Icon(Icons.edit_rounded, size: 20),
                          ),
                        ),
                        const Divider(height: 0),
                        // ListTile(
                        //   leading: const Icon(Icons.email_outlined),
                        //   title: const Text('Email'),
                        //   subtitle: Text(_profile?.email ?? '-'),
                        // ),
                        // if ((_profile?.phone ?? '').isNotEmpty) ...[
                        //   const Divider(height: 0),
                        //   ListTile(
                        //     leading: const Icon(Icons.phone_outlined),
                        //     title: const Text('Telepon'),
                        //     subtitle: Text(_profile?.phone ?? '-'),
                        //   ),
                        // ],
                        // const Divider(height: 0),
                        // ListTile(
                        //   leading: const Icon(Icons.calendar_today_outlined),
                        //   title: const Text('Bergabung pada'),
                        //   subtitle: Text(_profile?.createdAt ?? '-'),
                        // ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Secondary actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openEditDialog,
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Profil'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _confirmLogout,
                          icon: const Icon(Icons.logout_outlined),
                          label: const Text('Logout'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.red.shade200),
                            foregroundColor: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Tambahan credit
                  Center(
                    child: Text(
                      'By Ihsan Nur Huda',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                ],
              ),
            ),
    );
  }
}
