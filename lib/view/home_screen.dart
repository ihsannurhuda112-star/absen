// lib/view/home_screen.dart
import 'dart:io';
import 'package:absensi_san/models/attendance_statistics.dart';
import 'package:absensi_san/models/attendance_today.dart';
import 'package:absensi_san/service/api.dart';
import 'package:absensi_san/view/map_screen.dart';
import 'package:absensi_san/view/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:absensi_san/preference/preference_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  AttendanceToday? today;
  AttendanceStatistics? stat;
  bool isLoadingPage = false;
  bool isSubmitting = false;
  String userName = "User";

  String? profilePhotoUrl;

  // animation flags
  bool _animateIntro = false;
  bool _showStat1 = false;
  bool _showStat2 = false;
  bool _showStat3 = false;

  // palette
  static const Color accentPurple = Color(0xFF6C5CE7);
  static const Color softBackground = Color(0xFFE9F2FF);
  static const Color cardBg = Colors.white;
  static const Color cheeryGreen = Color(0xFF27AE60);
  static const Color cheeryOrange = Color(0xFFF39C12);
  static const Color hadirBg = Color(0xFFE8F5E9);
  static const Color izinBg = Color(0xFFE8F0FE);
  static const Color totalBg = Color(0xFFFFF7E6);

  String _resolveProfilePhotoUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.encodeFull(trimmed);
    }

    String path = trimmed.startsWith('/') ? trimmed : '/$trimmed';

    if (!path.contains('/public/') && path.contains('/profile_photo')) {
      path = path.replaceFirst('/profile_photo', '/public/profile_photo');
    }

    if (!path.startsWith('/') && path.contains('public/')) {
      path = '/$path';
    }

    final combined = '${AuthAPI.baseUrl}$path';
    return Uri.encodeFull(combined);
  }

  Position? _lastPosition;
  bool _cachedSudahAbsen = false;

  String? _displayAddress;
  bool _resolvingAddress = false;

  @override
  void initState() {
    super.initState();
    loadUserProfile();
    loadDashboard();

    // start intro animation after a short delay
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _animateIntro = true);

      // stagger stat cards
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _showStat1 = true);
      });
      Future.delayed(const Duration(milliseconds: 420), () {
        if (mounted) setState(() => _showStat2 = true);
      });
      Future.delayed(const Duration(milliseconds: 580), () {
        if (mounted) setState(() => _showStat3 = true);
      });
    });
  }

  Future<String?> _getAddressFromPosition(Position pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = <String>[];
      if ((p.street ?? '').isNotEmpty) parts.add(p.street!);
      if ((p.subLocality ?? '').isNotEmpty) parts.add(p.subLocality!);
      if ((p.locality ?? '').isNotEmpty) parts.add(p.locality!);
      if ((p.subAdministrativeArea ?? '').isNotEmpty)
        parts.add(p.subAdministrativeArea!);
      if (parts.isEmpty) {
        final fallback = [
          p.locality,
          p.administrativeArea,
          p.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        return fallback.isNotEmpty ? fallback : null;
      }
      return parts.join(', ');
    } catch (e) {
      debugPrint("Reverse geocoding failed: $e");
      return null;
    }
  }

  Future<void> _resolveAddressIfNeeded() async {
    if (_displayAddress != null || _resolvingAddress) return;
    _resolvingAddress = true;

    try {
      final serverAddress = today?.checkInAddress ?? today?.checkInAddress;
      if (serverAddress != null && serverAddress.trim().isNotEmpty) {
        _displayAddress = serverAddress.trim();
        return;
      }

      if (_lastPosition != null) {
        final addr = await _getAddressFromPosition(_lastPosition!);
        if (addr != null && addr.trim().isNotEmpty) {
          _displayAddress = addr;
          return;
        }
      }

      double? lat;
      double? lng;
      try {
        final dynamic t = today;
        if (t != null) {
          if (t.checkInLatitude != null && t.checkInLongitude != null) {
            lat = (t.checkInLatitude as num).toDouble();
            lng = (t.checkInLongitude as num).toDouble();
          } else if (t.lat != null && t.lng != null) {
            lat = (t.lat as num).toDouble();
            lng = (t.lng as num).toDouble();
          } else if (t.latitude != null && t.longitude != null) {
            lat = (t.latitude as num).toDouble();
            lng = (t.longitude as num).toDouble();
          }
        }
      } catch (_) {}

      if (lat != null && lng != null) {
        final pos = Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
        final addr = await _getAddressFromPosition(pos);
        if (addr != null && addr.trim().isNotEmpty) {
          _displayAddress = addr;
          return;
        }
      }
    } finally {
      _resolvingAddress = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> loadUserProfile() async {
    try {
      final Map<String, dynamic>? cached =
          await PreferenceHandler.getSavedProfile();
      if (cached != null) {
        final cachedName = (cached['name'] ?? cached['nama'] ?? '') as String?;
        final photo =
            (cached['profile_photo'] ?? cached['profilePhoto'] ?? '')
                as String?;
        if (!mounted) return;
        String? resolvedPhoto;
        if (photo != null && photo.isNotEmpty) {
          try {
            final resolved = _resolveProfilePhotoUrl(photo);
            resolvedPhoto = resolved.isNotEmpty ? resolved : null;
          } catch (_) {
            resolvedPhoto = photo;
          }
        }

        setState(() {
          if (cachedName != null && cachedName.isNotEmpty)
            userName = cachedName;
          profilePhotoUrl = resolvedPhoto;
        });
      }
    } catch (_) {}

    try {
      final profile = await AuthAPI.getProfile();
      if (!mounted) return;
      setState(() {
        userName = profile.name ?? "User";
      });

      try {
        final Map<String, dynamic>? updated =
            await PreferenceHandler.getSavedProfile();
        final rawPhoto = updated == null
            ? null
            : (updated['profile_photo'] ?? updated['profilePhoto']);
        if (rawPhoto is String && rawPhoto.isNotEmpty) {
          final resolved = _resolveProfilePhotoUrl(rawPhoto);
          if (!mounted) return;
          setState(
            () => profilePhotoUrl = resolved.isNotEmpty ? resolved : null,
          );
        } else {
          if (!mounted) return;
          setState(() => profilePhotoUrl = null);
        }
      } catch (_) {}
    } catch (e) {
      debugPrint("loadUserProfile failed: $e");
    }
  }

  Future<void> loadDashboard() async {
    setState(() => isLoadingPage = true);

    try {
      final Map<String, dynamic>? cachedJson =
          await PreferenceHandler.getTodayAttendance();
      AttendanceToday? cachedToday;
      if (cachedJson != null) {
        try {
          cachedToday = AttendanceToday.fromJson(cachedJson);
          final savedDate = cachedJson['attendance_date'] as String?;
          final todayStr = DateTime.now().toIso8601String().substring(0, 10);
          if (savedDate == null || savedDate != todayStr) {
            await PreferenceHandler.clearTodayAttendance();
            cachedToday = null;
          } else {
            if (mounted) {
              setState(() {
                today = cachedToday;
                _cachedSudahAbsen = cachedToday?.checkInTime != null;
                _displayAddress = cachedToday?.checkInAddress;
              });
            }
          }
        } catch (_) {
          await PreferenceHandler.clearTodayAttendance();
        }
      } else {
        final cachedFlag = await PreferenceHandler.getAbsenStatusToday();
        if (mounted) setState(() => _cachedSudahAbsen = cachedFlag);
      }

      // try restore coords from helper if cache didn't include them
      try {
        final coordsMap = await PreferenceHandler.getTodayCoords();
        final lat = coordsMap['check_in_lat'] ?? coordsMap['check_out_lat'];
        final lng = coordsMap['check_in_lng'] ?? coordsMap['check_out_lng'];
        if (lat != null && lng != null) {
          _lastPosition = Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        }
      } catch (_) {}

      final todayData = await AuthAPI.getToday();
      final statData = await AuthAPI.getStatistik();

      if (todayData != null) {
        await PreferenceHandler.saveTodayAttendance(todayData.toJson());
      }
      final didAbsen =
          (todayData != null) || (statData.sudahAbsenHariIni == true);
      await PreferenceHandler.saveAbsenStatusToday(didAbsen);

      if (!mounted) return;
      setState(() {
        today = todayData ?? today;
        stat = statData;
        _cachedSudahAbsen = didAbsen;

        try {
          final dynamic t = today;
          double? lat;
          double? lng;
          if (t != null) {
            if (t.checkInLatitude != null && t.checkInLongitude != null) {
              lat = (t.checkInLatitude as num).toDouble();
              lng = (t.checkInLongitude as num).toDouble();
            } else if (t.lat != null && t.lng != null) {
              lat = (t.lat as num).toDouble();
              lng = (t.lng as num).toDouble();
            } else if (t.latitude != null && t.longitude != null) {
              lat = (t.latitude as num).toDouble();
              lng = (t.longitude as num).toDouble();
            }
          }
          if (lat != null && lng != null) {
            _lastPosition = Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 0.0,
              altitude: 0.0,
              heading: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
              altitudeAccuracy: 0.0,
              headingAccuracy: 0.0,
            );
          }

          if ((today?.checkInAddress ?? '').isNotEmpty) {
            _displayAddress = today?.checkInAddress;
          } else {
            _displayAddress = null;
          }
        } catch (_) {}
      });

      await _resolveAddressIfNeeded();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal memuat dashboard: $e")));
    } finally {
      if (!mounted) return;
      setState(() => isLoadingPage = false);
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'Layanan lokasi tidak aktif';

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Izin lokasi ditolak';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Izin lokasi ditolak permanen';
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _doCheckIn() async {
    if (isSubmitting || !mounted) return;
    setState(() => isSubmitting = true);

    try {
      final pos = await _determinePosition();

      String? resolved = await _getAddressFromPosition(pos);
      final address = (resolved != null && resolved.isNotEmpty)
          ? resolved
          : "${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}";

      final ok = await AuthAPI.absenCheckIn(
        lat: pos.latitude,
        lng: pos.longitude,
        address: address,
      );

      if (ok) {
        final newToday = AttendanceToday(
          attendanceDate: DateFormat("yyyy-MM-dd").format(DateTime.now()),
          checkInTime: DateFormat("HH:mm").format(DateTime.now()),
          status: "masuk",
          checkInAddress: address,
        );

        if (!mounted) return;
        setState(() {
          today = newToday;
          _lastPosition = pos;
          _cachedSudahAbsen = true;
          _displayAddress = newToday.checkInAddress;
        });

        // save server object and coords to cache (atomic-ish)
        final saved = Map<String, dynamic>.from(newToday.toJson());
        saved['check_in_lat'] = pos.latitude;
        saved['check_in_lng'] = pos.longitude;
        await PreferenceHandler.saveTodayAttendance(saved);
        await PreferenceHandler.saveAbsenStatusToday(true);

        await Future.delayed(const Duration(milliseconds: 300));
        await _refreshStatsSilent();

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Berhasil Check In")));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Check In gagal")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal Check In: $e")));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _doCheckOut() async {
    if (isSubmitting || !mounted) return;
    setState(() => isSubmitting = true);

    try {
      final pos = await _determinePosition();

      String? resolved = await _getAddressFromPosition(pos);
      final address = (resolved != null && resolved.isNotEmpty)
          ? resolved
          : "${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}";

      final ok = await AuthAPI.absenCheckOut(
        lat: pos.latitude,
        lng: pos.longitude,
        address: address,
      );

      if (ok) {
        final updatedToday = AttendanceToday(
          attendanceDate: today?.attendanceDate,
          checkInTime: today?.checkInTime,
          checkOutTime: DateFormat("HH:mm").format(DateTime.now()),
          status: today?.status,
          checkInAddress: today?.checkInAddress,
          checkOutAddress: address,
        );

        if (!mounted) return;
        setState(() {
          today = updatedToday;
          _lastPosition = pos;
          _cachedSudahAbsen = true;
          _displayAddress =
              updatedToday.checkInAddress ?? updatedToday.checkOutAddress;
        });

        // save server object and coords to cache (atomic-ish)
        final saved = Map<String, dynamic>.from(updatedToday.toJson());
        saved['check_out_lat'] = pos.latitude;
        saved['check_out_lng'] = pos.longitude;
        try {
          final existing = await PreferenceHandler.getTodayAttendance();
          if (existing != null) {
            if (existing['check_in_lat'] != null)
              saved['check_in_lat'] = existing['check_in_lat'];
            if (existing['check_in_lng'] != null)
              saved['check_in_lng'] = existing['check_in_lng'];
          }
        } catch (_) {}
        await PreferenceHandler.saveTodayAttendance(saved);
        await PreferenceHandler.saveAbsenStatusToday(true);

        await Future.delayed(const Duration(milliseconds: 300));
        await _refreshStatsSilent();

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Berhasil Check Out")));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Check Out gagal")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal Check Out: $e")));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  // -------------------------
  // Updated showIzinDialog
  // -------------------------
  Future<void> showIzinDialog(BuildContext context) async {
    final dateCtrl = TextEditingController();
    final alasanCtrl = TextEditingController();
    dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final doSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ajukan Izin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tanggal (yyyy-MM-dd)',
                ),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.parse(dateCtrl.text),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null)
                    dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: alasanCtrl,
                decoration: const InputDecoration(labelText: 'Alasan izin'),
                minLines: 1,
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kirim'),
            ),
          ],
        );
      },
    );

    if (doSubmit != true) return;

    final date = dateCtrl.text.trim();
    final alasan = alasanCtrl.text.trim();
    if (date.isEmpty || alasan.isEmpty) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tanggal dan alasan wajib diisi')),
        );
      return;
    }

    // set submitting flag so buttons disable
    if (mounted) setState(() => isSubmitting = true);

    // show blocking progress dialog
    if (context.mounted)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

    try {
      // AuthAPI.submitIzin sometimes returns a Map (newer version) or void (older)
      final dynamic result = await AuthAPI.submitIzin(
        date: date,
        alasan: alasan,
      );

      // close progress dialog safely
      if (Navigator.canPop(context)) Navigator.pop(context);

      // handle both kinds of result
      if (result == null) {
        // assume success (older void-returning submitIzin)
        // refresh dashboard to pick any changes from server
        await loadDashboard();

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Izin terkirim")));
        }
      } else if (result is Map) {
        final bool success =
            result['success'] == true || result['status'] == null;
        final String message = (result['message'] ?? 'Sukses').toString();
        final Map<String, dynamic>? attendanceMap = result['attendance'] != null
            ? Map<String, dynamic>.from(result['attendance'])
            : null;

        if (success) {
          if (attendanceMap != null) {
            try {
              await PreferenceHandler.saveTodayAttendance(attendanceMap);
              await PreferenceHandler.saveAbsenStatusToday(true);
            } catch (_) {}
          }

          // refresh dashboard/statistik/history
          await _refreshStatsSilent();
          await loadDashboard();

          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
        } else {
          // non-success -> show message and still try to refresh
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
          await _refreshStatsSilent();
          await loadDashboard();
        }
      } else {
        // unknown response type: still refresh and show generic success
        await loadDashboard();
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Izin terkirim")));
        }
      }
    } catch (e) {
      // close progress dialog if still open
      if (Navigator.canPop(context)) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal kirim izin: $e')));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _refreshStatsSilent() async {
    try {
      final todayData = await AuthAPI.getToday();
      final statData = await AuthAPI.getStatistik();
      final didAbsen =
          (todayData != null) || (statData.sudahAbsenHariIni == true);

      if (todayData != null) {
        await PreferenceHandler.saveTodayAttendance(todayData.toJson());
      }
      await PreferenceHandler.saveAbsenStatusToday(didAbsen);

      // if cache has coords, prefer them to set _lastPosition
      try {
        final coordsMap = await PreferenceHandler.getTodayCoords();
        final lat = coordsMap['check_in_lat'] ?? coordsMap['check_out_lat'];
        final lng = coordsMap['check_in_lng'] ?? coordsMap['check_out_lng'];
        if (lat != null && lng != null) {
          _lastPosition = Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        today = todayData ?? today;
        stat = statData;
        _cachedSudahAbsen = didAbsen;
        try {
          final dynamic t = today;
          double? lat;
          double? lng;
          if (t != null) {
            if (t.checkInLatitude != null && t.checkInLongitude != null) {
              lat = (t.checkInLatitude as num).toDouble();
              lng = (t.checkInLongitude as num).toDouble();
            } else if (t.lat != null && t.lng != null) {
              lat = (t.lat as num).toDouble();
              lng = (t.lng as num).toDouble();
            } else if (t.latitude != null && t.longitude != null) {
              lat = (t.latitude as num).toDouble();
              lng = (t.longitude as num).toDouble();
            }
          }
          if (lat != null && lng != null) {
            _lastPosition = Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 0.0,
              altitude: 0.0,
              heading: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
              altitudeAccuracy: 0.0,
              headingAccuracy: 0.0,
            );
          }
        } catch (_) {}
      });

      await _resolveAddressIfNeeded();
    } catch (e) {
      debugPrint('Silent refresh failed: $e');
    }
  }

  Widget statCardColored({
    required String label,
    required int value,
    required Color bg,
    required Color valueColor,
    required bool visible,
  }) {
    return AnimatedScale(
      scale: visible ? 1.0 : 0.88,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Column(
            children: [
              Text(
                "$value",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: valueColor, // colored number
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700], // label color different from number
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openProfileAndRefresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    await loadUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayString = DateFormat("EEEE, dd MMMM yyyy", "id_ID").format(now);

    return Scaffold(
      backgroundColor: softBackground,
      body: isLoadingPage
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await loadDashboard();
                await loadUserProfile();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 6),

                  // Header - animated fade & slide
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 420),
                    opacity: _animateIntro ? 1 : 0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 420),
                      offset: _animateIntro
                          ? Offset.zero
                          : const Offset(0, 0.03),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFAF8FF), Color(0xFFF8F1FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _openProfileAndRefresh,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [accentPurple, Color(0xFFBFA6FF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: profilePhotoUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          profilePhotoUrl!,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return const CircleAvatar(
                                                  radius: 32,
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 38,
                                                  ),
                                                );
                                              },
                                        ),
                                      )
                                    : const CircleAvatar(
                                        radius: 32,
                                        child: Icon(Icons.person, size: 38),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Hai, $userName",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Selamat bekerja ✨",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  todayString,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Buka Profil',
                              icon: const Icon(Icons.account_circle_outlined),
                              onPressed: _openProfileAndRefresh,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Absen card - also animated
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 420),
                    opacity: _animateIntro ? 1 : 0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 420),
                      offset: _animateIntro
                          ? Offset.zero
                          : const Offset(0, 0.03),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 10),
                          ],
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: accentPurple.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.access_time,
                                    color: accentPurple,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Absen Hari Ini",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      "Jam Masuk",
                                      style: TextStyle(color: Colors.black87),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      today?.checkInTime ?? "-",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: cheeryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      "Jam Pulang",
                                      style: TextStyle(color: Colors.black87),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      today?.checkOutTime ?? "-",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: today?.checkOutTime != null
                                            ? Colors.red
                                            : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed:
                                  (!isSubmitting &&
                                      !_cachedSudahAbsen &&
                                      (today?.checkInTime == null))
                                  ? _doCheckIn
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentPurple.withOpacity(0.12),
                                foregroundColor: accentPurple,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 10,
                                ),
                              ),
                              child: const Text("MASUK"),
                            ),
                            const SizedBox(height: 10),

                            if (_displayAddress != null ||
                                _lastPosition != null) ...[
                              Text(
                                "Lokasi terakhir: " +
                                    (_displayAddress != null
                                        ? _displayAddress!
                                        : "${_lastPosition!.latitude.toStringAsFixed(5)}, ${_lastPosition!.longitude.toStringAsFixed(5)}"),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    double? lat = _lastPosition?.latitude;
                                    double? lng = _lastPosition?.longitude;
                                    if (lat != null && lng != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MapScreen(
                                            latitude: lat,
                                            longitude: lng,
                                            title: "Lokasi Absen Hari Ini",
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Koordinat tidak tersedia",
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.map,
                                    color: Color(0xFF6A4CFF),
                                  ),
                                  label: const Text(
                                    "Lihat di Map",
                                    style: TextStyle(color: Color(0xFF6A4CFF)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Buttons
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cheeryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        onPressed:
                            (!isSubmitting &&
                                !_cachedSudahAbsen &&
                                (today?.checkInTime == null))
                            ? _doCheckIn
                            : null,
                        child: const Text(
                          "CHECK IN",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cheeryOrange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        onPressed:
                            (!isSubmitting &&
                                (today?.checkInTime != null) &&
                                (today?.checkOutTime == null))
                            ? _doCheckOut
                            : null,
                        child: const Text(
                          "CHECK OUT",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // small gap then IZIN button
                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: (!isSubmitting)
                            ? () => showIzinDialog(context)
                            : null,
                        icon: const Icon(Icons.event_busy_outlined),
                        label: const Text("AJUKAN IZIN"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.blue.shade200),
                          foregroundColor: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Statistik header
                  const Text(
                    "Statistik Kehadiran",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Stat cards row (Hadir, Izin)
                  Row(
                    children: [
                      Expanded(
                        child: statCardColored(
                          label: "Hadir",
                          value: stat?.totalMasuk ?? 0,
                          bg: hadirBg,
                          valueColor: cheeryGreen,
                          visible: _showStat1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: statCardColored(
                          label: "Izin",
                          value: stat?.totalIzin ?? 0,
                          bg: izinBg,
                          valueColor: Colors.blue.shade700,
                          visible: _showStat2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Total Absen full width
                  AnimatedScale(
                    scale: _showStat3 ? 1 : 0.92,
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity: _showStat3 ? 1 : 0,
                      duration: const Duration(milliseconds: 320),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: totalBg,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "${stat?.totalAbsen ?? 0}",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: cheeryOrange,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Total Absen",
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
