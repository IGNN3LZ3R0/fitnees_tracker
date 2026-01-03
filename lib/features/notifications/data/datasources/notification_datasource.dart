import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:ui';

/// DataSource para notificaciones usando flutter_local_notifications plugin
///
/// MIGRACIÓN COMPLETADA: Ya no usa Platform Channels
/// ✅ Usa flutter_local_notifications directamente
/// ✅ Código 100% Dart (sin Kotlin)
/// ✅ Multiplataforma (Android + iOS)
abstract class NotificationDataSource {
  Future<bool> requestPermissions();
  Future<void> showStepGoalNotification(int steps);
  Future<void> showFallDetectionAlert();
  Future<void> initialize();
}

class NotificationDataSourceImpl implements NotificationDataSource {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // IDs únicos para cada tipo de notificación
  static const int _stepGoalNotificationId = 1;
  static const int _fallAlertNotificationId = 2;

  @override
  Future<void> initialize() async {
    // Configuración Android
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración iOS (opcional, para cuando expandes a iOS)
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    print('✅ Notificaciones inicializadas con plugin');
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Notificación presionada: ${response.payload}');
    // Aquí puedes navegar a una pantalla específica
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      // Solicitar permisos en Android 13+
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        if (!status.isGranted) {
          print('⚠️ Permisos de notificación denegados');
          return false;
        }
      }

      // Verificar permisos usando permission_handler (compatible)
      final status = await Permission.notification.status;
      final granted = status.isGranted;

      print(granted
          ? '✅ Permisos de notificación concedidos'
          : '❌ Permisos de notificación denegados');

      return granted;
    } catch (e) {
      print('❌ Error solicitando permisos de notificación: $e');
      return false;
    }
  }

  @override
  Future<void> showStepGoalNotification(int steps) async {
    try {
      // Configuración de la notificación
      final androidDetails = AndroidNotificationDetails(
        'fitness_channel', // Canal ID
        'Fitness Notifications', // Nombre del canal
        channelDescription: 'Notificaciones de logros de fitness',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        color: const Color(0xFF6366F1), // Color del icono
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      // Mostrar notificación
      await _notifications.show(
        _stepGoalNotificationId,
        '🎉 ¡Meta alcanzada!',
        'Has caminado $steps pasos. ¡Sigue así!',
        notificationDetails,
        payload: 'step_goal:$steps',
      );

      print('✅ Notificación de meta de pasos mostrada: $steps pasos');
    } catch (e) {
      print('❌ Error mostrando notificación de pasos: $e');
    }
  }

  @override
  Future<void> showFallDetectionAlert() async {
    try {
      // Configuración de alerta crítica
      final androidDetails = AndroidNotificationDetails(
        'fitness_channel',
        'Fitness Notifications',
        channelDescription: 'Alertas de seguridad',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
        color: const Color(0xFFEF4444), // Color rojo para alerta
        category: AndroidNotificationCategory.alarm,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      // Mostrar alerta
      await _notifications.show(
        _fallAlertNotificationId,
        '⚠️ Caída detectada',
        'Se ha detectado una posible caída. ¿Estás bien?',
        notificationDetails,
        payload: 'fall_alert',
      );

      print('⚠️ Alerta de caída mostrada');
    } catch (e) {
      print('❌ Error mostrando alerta de caída: $e');
    }
  }

  /// Cancelar una notificación específica
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
