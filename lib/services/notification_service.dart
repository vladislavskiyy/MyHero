// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Сервис локальных уведомлений на основе flutter_local_notifications и timezone.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Инициализация сервиса уведомлений
  Future<void> init() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();

      const androidInitSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosInitSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: iosInitSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      // On this package version, Android notification permission is not exposed by
      // the platform implementation here, so we skip the extra call and rely on
      // the app-level permission flow instead.
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    // Здесь можно обработать клик по уведомлению (payload), если нужно
  }

  /// Запланировать одноразовое уведомление (например, за 30 минут до дедлайна).
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (!_initialized) return;

    try {
      final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      );
      if (scheduledTZ.isBefore(tz.TZDateTime.now(tz.local))) return;

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'one_time_channel',
            'Одноразовые уведомления',
            channelDescription: 'Канал для уведомлений с привязкой ко времени',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (_) {
      // Фоллбек: если платформа или среда не поддерживают уведомления, ничего не делаем.
    }
  }

  /// Отменить уведомление по его ID
  Future<void> cancel(int id) async {
    if (!_initialized) return;

    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
    } catch (_) {
      // ignore
    }
  }

  /// Отменить все уведомления
  Future<void> cancelAll() async {
    if (!_initialized) return;

    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
    } catch (_) {
      // ignore
    }
  }
}
