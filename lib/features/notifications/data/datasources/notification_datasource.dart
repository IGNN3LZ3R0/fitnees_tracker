import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/platform/platform_channels.dart';

/// DataSource para notificaciones usando Platform Channel
///
/// EXPLICACIÓN:
/// - Usa MethodChannel para comunicarse con código nativo Android
/// - Maneja permisos de notificaciones (Android 13+)
abstract class NotificationDataSource {
  Future<bool> requestPermissions();
  Future<void> showStepGoalNotification(int steps);
  Future<void> showFallDetectionAlert();
}

class NotificationDataSourceImpl implements NotificationDataSource {
  final MethodChannel _channel = const MethodChannel(
    PlatformChannels.notifications
  );

  @override
  Future<bool> requestPermissions() async {
    try {
      // En Android 13+ se requiere permiso explícito
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      print('Error solicitando permisos de notificación: $e');
      return false;
    }
  }

  @override
  Future<void> showStepGoalNotification(int steps) async {
    try {
      await _channel.invokeMethod('showStepGoalNotification', {
        'steps': steps,
      });
    } on PlatformException catch (e) {
      print('Error mostrando notificación de pasos: ${e.message}');
    }
  }

  @override
  Future<void> showFallDetectionAlert() async {
    try {
      await _channel.invokeMethod('showFallAlert');
    } on PlatformException catch (e) {
      print('Error mostrando alerta de caída: ${e.message}');
    }
  }
}