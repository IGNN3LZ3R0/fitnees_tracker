import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/step_data.dart';

/// DataSource para acelerómetro usando el plugin sensors_plus

abstract class AccelerometerDataSource {
  Stream<StepData> get stepStream;
  Future<void> startCounting();
  Future<void> stopCounting();
  Future<bool> requestPermissions();
}

class AccelerometerDataSourceImpl implements AccelerometerDataSource {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final StreamController<StepData> _stepController = StreamController.broadcast();
  
  // Variables de estado
  int _stepCount = 0;
  double _lastMagnitude = 0.0;
  final List<double> _magnitudeHistory = [];
  final int _historySize = 15;
  int _sampleCount = 0;
  String _lastActivityType = 'stationary';
  int _activityConfidence = 0;
  bool _isRunning = false;

  @override
  Stream<StepData> get stepStream => _stepController.stream;

  @override
  Future<bool> requestPermissions() async {
    // En Android 13+ se requiere permiso de sensores corporales
    if (await Permission.sensors.isPermanentlyDenied) {
      print('Permiso de sensores permanentemente denegado');
      return false;
    }

    final sensorsStatus = await Permission.sensors.request();
    final activityStatus = await Permission.activityRecognition.request();
    
    return sensorsStatus.isGranted && activityStatus.isGranted;
  }

  @override
  Future<void> startCounting() async {
    if (_isRunning) return;
    
    _isRunning = true;
    _stepCount = 0;
    _magnitudeHistory.clear();
    
    print('Iniciando contador de pasos con sensors_plus...');

    // Suscribirse a eventos del acelerómetro
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval, // ~60Hz
    ).listen((AccelerometerEvent event) {
      _processAccelerometerData(event);
    });
  }

  @override
  Future<void> stopCounting() async {
    _isRunning = false;
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    print('Contador de pasos detenido');
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    // Calcular magnitud del vector de aceleración
    final magnitude = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );

    // Mantener historial para suavizado
    _magnitudeHistory.add(magnitude);
    if (_magnitudeHistory.length > _historySize) {
      _magnitudeHistory.removeAt(0);
    }

    final avgMagnitude = _magnitudeHistory.reduce((a, b) => a + b) / 
                        _magnitudeHistory.length;

    // Detectar paso (umbral ajustado)
    if (magnitude > 14 && _lastMagnitude <= 14) {
      _stepCount++;
    }
    _lastMagnitude = magnitude;

    // Detectar tipo de actividad
    final newActivityType = _detectActivityType(avgMagnitude);
    
    if (newActivityType == _lastActivityType) {
      _activityConfidence++;
    } else {
      _activityConfidence = 0;
    }

    final finalActivityType = _activityConfidence >= 5 
        ? newActivityType 
        : _lastActivityType;
    _lastActivityType = newActivityType;

    // Enviar datos cada 5 muestras
    _sampleCount++;
    if (_sampleCount >= 5) {
      _sampleCount = 0;
      
      final stepData = StepData(
        stepCount: _stepCount,
        activityType: _parseActivityType(finalActivityType),
        magnitude: avgMagnitude,
      );

      _stepController.add(stepData);
    }
  }

  String _detectActivityType(double avgMagnitude) {
    if (avgMagnitude < 10.8) return 'stationary';
    if (avgMagnitude < 14.0) return 'walking';
    return 'running';
  }

  ActivityType _parseActivityType(String type) {
    switch (type) {
      case 'walking': return ActivityType.walking;
      case 'running': return ActivityType.running;
      default: return ActivityType.stationary;
    }
  }

  void dispose() {
    _accelerometerSubscription?.cancel();
    _stepController.close();
  }
}