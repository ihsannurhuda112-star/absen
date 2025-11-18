import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String title;

  const MapScreen({
    super.key,
    this.latitude,
    this.longitude,
    this.title = "Lokasi Absen",
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _position;
  Marker? _marker;
  String _currentAddress = "Mengambil alamat...";

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    if (widget.latitude != null && widget.longitude != null) {
      _setMarker(LatLng(widget.latitude!, widget.longitude!));
    } else {
      await _getDeviceLocation();
    }
  }

  Future<void> _getDeviceLocation() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _setMarker(LatLng(pos.latitude, pos.longitude));
  }

  Future<void> _setMarker(LatLng pos) async {
    final placemarks = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    );
    final place = placemarks.first;

    setState(() {
      _position = pos;
      _marker = Marker(
        markerId: const MarkerId("absen"),
        position: pos,
        infoWindow: InfoWindow(
          title: "Lokasi",
          snippet: "${place.street}, ${place.locality}",
        ),
      );
      _currentAddress = "${place.street}, ${place.locality}, ${place.country}";
    });

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-6.2000, 106.816666),
                zoom: 12,
              ),
              myLocationEnabled: true,
              markers: _marker != null ? {_marker!} : {},
              onMapCreated: (c) => _mapController = c,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            width: double.infinity,
            color: Colors.white,
            child: Text(_currentAddress, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
