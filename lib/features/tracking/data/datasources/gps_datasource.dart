import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/location_point.dart';

/// DataSource para GPS usando el plugin geolocator

abstract class GpsDataSource {
  Future<LocationPoint?> getCurrentLocation();
  Stream<LocationPoint> get locationStream;
  Future<bool> isGpsEnabled();
  Future<bool> requestPermissions();
}

class GpsDataSourceImpl implements GpsDataSource {
  StreamController<LocationPoint>? _locationController;

  @override
  Future<bool> isGpsEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<bool> requestPermissions() async {
    // Verificar servicios de ubicación
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Servicios de ubicacion deshabilitados');
      return false;
    }

    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Permisos de ubicacion denegados');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Permisos de ubicacion denegados permanentemente');
      return false;
    }

    print('Permisos de ubicacion concedidos');
    return true;
  }

  @override
  Future<LocationPoint?> getCurrentLocation() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return _positionToLocationPoint(position);
    } catch (e) {
      print('Error obteniendo ubicacion actual: $e');
      return null;
    }
  }

  @override
  Stream<LocationPoint> get locationStream {
    _locationController ??= StreamController<LocationPoint>.broadcast(
      onListen: _startLocationUpdates,
      onCancel: _stopLocationUpdates,
    );
    return _locationController!.stream;
  }

  StreamSubscription<Position>? _positionSubscription;

  void _startLocationUpdates() {
    print('Iniciando stream de ubicaciones...');

    // Configuración de precisión
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // Mínimo 2 metros de cambio
      timeLimit: Duration(seconds: 30),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        final locationPoint = _positionToLocationPoint(position);
        _locationController?.add(locationPoint);
        
        print('Nueva ubicación: '
              'lat=${position.latitude.toStringAsFixed(6)}, '
              'lon=${position.longitude.toStringAsFixed(6)}, '
              'acc=${position.accuracy.toStringAsFixed(1)}m');
      },
      onError: (error) {
        print('Error en stream de ubicacion: $error');
        _locationController?.addError(error);
      },
    );
  }

  void _stopLocationUpdates() {
    print('Deteniendo stream de ubicaciones');
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  LocationPoint _positionToLocationPoint(Position position) {
    return LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: position.speed,
      accuracy: position.accuracy,
      timestamp: position.timestamp ?? DateTime.now(),
    );
  }

  void dispose() {
    _stopLocationUpdates();
    _locationController?.close();
  }
}