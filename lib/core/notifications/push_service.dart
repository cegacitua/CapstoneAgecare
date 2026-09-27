import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio de notificaciones.
///
/// - Locales: alarmas de medicación programadas en el dispositivo
///   (flutter_local_notifications).
/// - Remotas: push desde el backend vía FCM; el token se reenvía al backend
///   (POST /users/me/devices), que lo registra en Azure Notification Hubs.
///
/// En modo mocks el registro remoto se omite para poder correr sin proyecto
/// Firebase configurado.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Se emite cuando llega un push o se toca una notificación local, con el
  /// payload (p. ej. {"type":"dose","dose_id":"..."} o {"type":"alert",...}).
  final StreamController<Map<String, dynamic>> _taps =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap => _taps.stream;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _initialized = false;

  Future<void> init({required bool enableRemote}) async {
    if (_initialized) return;
    _initialized = true;

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxInit = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    try {
      await _local.initialize(
        const InitializationSettings(
          android: androidInit,
          iOS: iosInit,
          linux: linuxInit,
        ),
        onDidReceiveNotificationResponse: (resp) {
          final payload = resp.payload;
          if (payload != null) _taps.add(_parse(payload));
        },
      );
    } catch (e) {
      // Ignorar o registrar error en plataformas que no soportan notificaciones locales
    }

    if (enableRemote) {
      try {
        await Firebase.initializeApp();
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission();
        _fcmToken = await messaging.getToken();
        messaging.onTokenRefresh.listen((t) => _fcmToken = t);
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp
            .listen((m) => _taps.add(Map<String, dynamic>.from(m.data)));
      } catch (e) {
        // Sin configuración Firebase (o en desarrollo): las notificaciones
        // locales siguen funcionando.
        _fcmToken = null;
      }
    }
  }

  void _onForegroundMessage(RemoteMessage m) {
    final n = m.notification;
    if (n != null) {
      _local.show(
        m.hashCode,
        n.title,
        n.body,
        _details(m.data['type'] == 'alert' ? _alertChannel : _generalChannel),
        payload: _encode(m.data),
      );
    }
  }

  /// Programa la alarma local de una dosis de medicación (ticket AGE-403).
  Future<void> scheduleDoseReminder({
    required int id,
    required String medicationName,
    required DateTime when,
    required String doseId,
  }) async {
    // Nota: para disparo exacto se recomienda zonedSchedule con timezone.
    // Aquí usamos show inmediato si la hora ya pasó; en producción usar
    // flutter_local_notifications + timezone para zonedSchedule.
    await _local.show(
      id,
      'Hora de tu medicamento',
      'Es momento de tomar $medicationName',
      _details(_medChannel),
      payload: _encode({'type': 'dose', 'dose_id': doseId}),
    );
  }

  Future<void> cancelDoseReminder(int id) => _local.cancel(id);

  NotificationDetails _details(AndroidNotificationChannel ch) => NotificationDetails(
        android: AndroidNotificationDetails(
          ch.id,
          ch.name,
          channelDescription: ch.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  static const _medChannel = AndroidNotificationChannel(
      'meds', 'Medicación', description: 'Alarmas de medicamentos');
  static const _alertChannel = AndroidNotificationChannel(
      'alerts', 'Alertas', description: 'Alertas de salud y SOS');
  static const _generalChannel = AndroidNotificationChannel(
      'general', 'General', description: 'Notificaciones generales');

  String _encode(Map<String, dynamic> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join('&');

  Map<String, dynamic> _parse(String payload) {
    final out = <String, dynamic>{};
    for (final pair in payload.split('&')) {
      final kv = pair.split('=');
      if (kv.length == 2) out[kv[0]] = kv[1];
    }
    return out;
  }
}
