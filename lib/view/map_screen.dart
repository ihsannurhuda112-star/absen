// lib/view/map_screen.dart
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  /// Jika latitude/longitude diberikan -> peta akan center ke situ.
  /// Jika [selectable] true -> user bisa tap/drag marker dan menekan konfirmasi.
  final double? latitude;
  final double? longitude;
  final String title;
  final bool selectable; // jika true -> tombol konfirmasi muncul
  final String confirmLabel; // label tombol konfirmasi (mis. "Pilih Lokasi")

  const MapScreen({
    super.key,
    this.latitude,
    this.longitude,
    this.title = "Lokasi Absen",
    this.selectable = false,
    this.confirmLabel = "Konfirmasi Lokasi",
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _position;
  Marker? _marker;
  String _currentAddress = "Mengambil alamat...";
  bool _loadingAddress = false;
  bool _locating = false;

  static const CameraPosition _defaultCam = CameraPosition(
    target: LatLng(-6.2000, 106.816666),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _loadInitialLocation();
  }

  Future<void> _loadInitialLocation() async {
    if (widget.latitude != null && widget.longitude != null) {
      final pos = LatLng(widget.latitude!, widget.longitude!);
      await _setMarker(pos, animate: false);
      _moveCamera(pos, zoom: 16);
    } else {
      // try device location
      await _getDeviceLocation();
    }
  }

  Future<void> _getDeviceLocation() async {
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          throw Exception('Izin lokasi ditolak');
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latlng = LatLng(pos.latitude, pos.longitude);
      await _setMarker(latlng, animate: true);
      _moveCamera(latlng, zoom: 16);
    } catch (e) {
      // fallback: tetap di default camera
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ambil lokasi device: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _moveCamera(LatLng pos, {double zoom = 16}) async {
    try {
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: pos, zoom: zoom),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _setMarker(LatLng pos, {bool animate = true}) async {
    setState(() {
      _marker = Marker(
        markerId: const MarkerId('absen_marker'),
        position: pos,
        draggable: widget.selectable,
        onDragEnd: (p) {
          _onMarkerMoved(p);
        },
      );
      _position = pos;
      _loadingAddress = true;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];
        if ((p.street ?? '').isNotEmpty) parts.add(p.street!);
        if ((p.subLocality ?? '').isNotEmpty) parts.add(p.subLocality!);
        if ((p.locality ?? '').isNotEmpty) parts.add(p.locality!);
        if ((p.subAdministrativeArea ?? '').isNotEmpty)
          parts.add(p.subAdministrativeArea!);
        if ((p.administrativeArea ?? '').isNotEmpty)
          parts.add(p.administrativeArea!);
        final addr = parts.isNotEmpty
            ? parts.join(', ')
            : '${p.locality ?? ''} ${p.country ?? ''}'.trim();
        if (mounted) setState(() => _currentAddress = addr);
      } else {
        if (mounted)
          setState(
            () => _currentAddress =
                '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
          );
      }
    } catch (e) {
      if (mounted)
        setState(
          () => _currentAddress =
              '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
        );
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
      if (animate) _moveCamera(pos, zoom: 16);
    }
  }

  Future<void> _onMarkerMoved(LatLng pos) async {
    await _setMarker(pos, animate: false);
  }

  Future<void> _onMapTapped(LatLng pos) async {
    if (!widget.selectable) return;
    await _setMarker(pos);
  }

  Future<void> _openExternalMaps() async {
    if (_position == null) return;
    final lat = _position!.latitude;
    final lng = _position!.longitude;
    final googleUri = Uri.parse(
      'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(widget.title)})',
    );
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(googleUri)) {
      await launchUrl(googleUri);
      return;
    }
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka aplikasi peta.')),
      );
  }

  /// Confirm selected location and return result to caller.
  /// result: { 'lat': double, 'lng': double, 'address': String }
  void _confirmAndReturn() {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih lokasi terlebih dahulu')),
      );
      return;
    }
    final result = {
      'lat': _position!.latitude,
      'lng': _position!.longitude,
      'address': _currentAddress,
    };
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = widget.selectable && _position != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Lokasi saya',
            icon: const Icon(Icons.my_location),
            onPressed: _getDeviceLocation,
          ),
          if (_position != null)
            IconButton(
              tooltip: 'Buka di Maps',
              icon: const Icon(Icons.open_in_new),
              onPressed: _openExternalMaps,
            ),
          IconButton(
            tooltip: 'Salin koordinat',
            icon: const Icon(Icons.copy),
            onPressed: () {
              if (_position == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Koordinat tidak tersedia')),
                );
                return;
              }
              final t =
                  '${_position!.latitude.toStringAsFixed(6)},${_position!.longitude.toStringAsFixed(6)}';
              Clipboard.setData(ClipboardData(text: t));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Koordinat disalin')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _defaultCam,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (c) {
              _mapController = c;
              // if we already had a position set earlier, animate to it:
              if (_position != null) {
                _moveCamera(_position!, zoom: 16);
              }
            },
            markers: _marker != null ? {_marker!} : {},
            onTap: _onMapTapped,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // bottom info + action area
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // address card
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _loadingAddress
                                      ? const SizedBox(
                                          height: 12,
                                          child: LinearProgressIndicator(),
                                        )
                                      : Text(
                                          _currentAddress,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                IconButton(
                                  tooltip: 'Center ke lokasi saya',
                                  onPressed: _getDeviceLocation,
                                  icon: const Icon(Icons.my_location),
                                ),
                                IconButton(
                                  tooltip: 'Konfirmasi (jika memilih)',
                                  onPressed: canConfirm
                                      ? _confirmAndReturn
                                      : null,
                                  icon: const Icon(Icons.check_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // if selectable show confirm button prominent
                    if (widget.selectable)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: Text(widget.confirmLabel),
                          onPressed: canConfirm ? _confirmAndReturn : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
