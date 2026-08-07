import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final String address;
  final double accuracy;
  final DateTime timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.accuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String? ?? '',
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LocationData? _cachedLocation;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(seconds: 45);

  /// Check whether location permission is granted
  Future<bool> isPermissionGranted() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Request location permission
  Future<PermissionStatus> requestPermission() async {
    return await Permission.location.request();
  }

  /// Get current device location with caching for performance
  Future<LocationData?> getCurrentLocation({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedLocation != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _cachedLocation;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      String address = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 5));

        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [p.name, p.locality, p.administrativeArea, p.country]
              .where((s) => s != null && s.trim().isNotEmpty)
              .toList();
          address = parts.join(', ');
        }
      } catch (_) {
        address = 'Coordinates: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      _cachedLocation = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );
      _lastFetchTime = DateTime.now();

      return _cachedLocation;
    } catch (_) {
      return _cachedLocation;
    }
  }

  /// Calculate distance in meters between two coordinates
  double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Check if student is within allowed radius (in meters) of teacher
  bool isWithinRadius({
    required LocationData teacherLocation,
    required LocationData studentLocation,
    double radiusMeters = 100.0,
  }) {
    final distance = calculateDistance(
      startLatitude: teacherLocation.latitude,
      startLongitude: teacherLocation.longitude,
      endLatitude: studentLocation.latitude,
      endLongitude: studentLocation.longitude,
    );
    return distance <= radiusMeters;
  }
}
