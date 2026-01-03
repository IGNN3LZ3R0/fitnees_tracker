import 'package:flutter/material.dart';
import 'dart:async';
import '../../../auth/data/datasources/accelerometer_datasource.dart';
import '../../../auth/domain/entities/step_data.dart';
import '../../../notifications/data/datasources/notification_datasource.dart';

class StepCounterWidget extends StatefulWidget {
  const StepCounterWidget({super.key});

  @override
  State<StepCounterWidget> createState() => _StepCounterWidgetState();
}

class _StepCounterWidgetState extends State<StepCounterWidget> {
  final AccelerometerDataSource _dataSource = AccelerometerDataSourceImpl();
  final NotificationDataSource _notificationDataSource = NotificationDataSourceImpl();

  StreamSubscription<StepData>? _subscription;
  StepData? _currentData;
  bool _isTracking = false;
  bool _goalNotificationSent = false;
  bool _hasNotificationPermission = false;
  DateTime? _lastFallDetectionTime;
  bool _fallDialogShown = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // NUEVO: Inicializar plugin de notificaciones
  // ═══════════════════════════════════════════════════════════
  Future<void> _initializeNotifications() async {
    await _notificationDataSource.initialize();
    await _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    final granted = await _notificationDataSource.requestPermissions();
    setState(() {
      _hasNotificationPermission = granted;
    });
  }

  void _toggleTracking() {
    if (_isTracking) {
      _stopTracking();
    } else {
      _startTracking();
    }
  }

  void _startTracking() async {
    final hasPermission = await _dataSource.requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permisos de sensores denegados'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await _dataSource.startCounting();
    _goalNotificationSent = false;

    _subscription = _dataSource.stepStream.listen(
      (data) {
        setState(() {
          _currentData = data;
        });

        // Notificación al alcanzar 30 pasos
        if (data.stepCount >= 30 && !_goalNotificationSent && _hasNotificationPermission) {
          _goalNotificationSent = true;
          _notificationDataSource.showStepGoalNotification(data.stepCount);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.celebration, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('¡Meta alcanzada! ${data.stepCount} pasos'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }

        // Detección de caídas
        if (data.isPossibleFall && _hasNotificationPermission && !_fallDialogShown) {
          final now = DateTime.now();
          if (_lastFallDetectionTime == null || 
              now.difference(_lastFallDetectionTime!).inSeconds > 10) {
            
            _lastFallDetectionTime = now;
            _fallDialogShown = true;
            
            _notificationDataSource.showFallDetectionAlert();
            
            if (mounted) {
              _showFallAlertDialog();
            }
          }
        }
      },
      onError: (error) {
        print('Error en stream: $error');
      },
    );

    setState(() {
      _isTracking = true;
    });
  }

  void _stopTracking() async {
    await _dataSource.stopCounting();
    _subscription?.cancel();

    setState(() {
      _isTracking = false;
    });
  }

  void _showFallAlertDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
              SizedBox(width: 8),
              Expanded(child: Text('Caída Detectada')),
            ],
          ),
          content: const Text(
            '⚠️ Se ha detectado una posible caída.\n\n'
            '¿Estás bien?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _fallDialogShown = false;
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Estoy bien', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _fallDialogShown = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contactando a emergencias...'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Necesito ayuda', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contador de Pasos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleTracking,
                  icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                  label: Text(_isTracking ? 'Detener' : 'Iniciar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTracking ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            if (!_hasNotificationPermission && _isTracking)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_off, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Notificaciones desactivadas',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _requestNotificationPermissions,
                      child: const Text('Activar'),
                    ),
                  ],
                ),
              ),
            
            const Divider(),

            Text(
              '${_currentData?.stepCount ?? 0}',
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6366F1),
              ),
            ),
            const Text('pasos', style: TextStyle(fontSize: 16, color: Colors.grey)),
            
            if (_isTracking)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: ((_currentData?.stepCount ?? 0) / 30).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_currentData?.stepCount ?? 0)}/30 pasos hacia la meta',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoChip(
                  icon: _getActivityIcon(_currentData?.activityType),
                  label: _getActivityLabel(_currentData?.activityType),
                  color: Colors.blue,
                ),
                _buildInfoChip(
                  icon: Icons.local_fire_department,
                  label: '${_currentData?.estimatedCalories.toStringAsFixed(1) ?? "0"} cal',
                  color: Colors.orange,
                ),
              ],
            ),
            
            if (_isTracking)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.health_and_safety, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Detección de caídas: ${(_currentData?.magnitude ?? 0).toStringAsFixed(1)} m/s²',
                        style: const TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  IconData _getActivityIcon(ActivityType? type) {
    switch (type) {
      case ActivityType.walking:
        return Icons.directions_walk;
      case ActivityType.running:
        return Icons.directions_run;
      case ActivityType.stationary:
        return Icons.accessibility_new;
      default:
        return Icons.help_outline;
    }
  }

  String _getActivityLabel(ActivityType? type) {
    switch (type) {
      case ActivityType.walking:
        return 'Caminando';
      case ActivityType.running:
        return 'Corriendo';
      case ActivityType.stationary:
        return 'Quieto';
      default:
        return 'Detectando...';
    }
  }
}