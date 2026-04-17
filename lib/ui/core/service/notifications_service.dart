import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const String _defaultChannelId = 'voxfinance_default_channel';
  static const String _backupChannelId = 'voxfinance_backup_auto';

  static const int idBackupProgress = 9201;
  static const int idBackupResult = 9202;
  static const int idBackupPending = 9203;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Android 13+ (API 33): pede permissão de notificação.
  static Future<bool?> requestAndroidPostNotificationsPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.requestNotificationsPermission();
  }

  /// Notificação simples imediata
  static Future<void> showNow({
    required String title,
    required String body,
    int id = 0,
  }) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      _defaultChannelId,
      'Notificações VoxFinance',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> showBackupInProgress() async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      _backupChannelId,
      'Backup automático na nuvem',
      channelDescription:
          'Avisos de início e fim do backup automático na nuvem.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      onlyAlertOnce: true,
    );
    await _plugin.show(
      idBackupProgress,
      'Backup na nuvem',
      'Enviando dados…',
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> cancelBackupProgress() async {
    await init();
    await _plugin.cancel(idBackupProgress);
  }

  static Future<void> showBackupSuccess() async {
    await init();
    await cancelBackupProgress();
    final hora = DateFormat.Hm().format(DateTime.now());
    const androidDetails = AndroidNotificationDetails(
      _backupChannelId,
      'Backup automático na nuvem',
      channelDescription:
          'Avisos de início e fim do backup automático na nuvem.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.show(
      idBackupResult,
      'Backup concluído',
      'Backup na nuvem finalizado com sucesso ($hora).',
      const NotificationDetails(android: androidDetails),
    );
  }

  static bool _pareceFalhaDeRede(Object e) {
    if (e is SocketException) return true;
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network is unreachable') ||
        s.contains('connection refused') ||
        s.contains('connection timed out') ||
        s.contains('connection reset') ||
        s.contains('host lookup') ||
        s.contains('network');
  }

  static String _encurtar(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  static Future<void> showBackupFailed(Object error) async {
    await init();
    await cancelBackupProgress();
    final rede = _pareceFalhaDeRede(error);
    final title = rede ? 'Backup pendente' : 'Backup falhou';
    final body = rede
        ? 'Sem conexão ou rede instável. O próximo horário agendado tentará de novo.'
        : _encurtar(error.toString(), 220);
    const androidDetails = AndroidNotificationDetails(
      _backupChannelId,
      'Backup automático na nuvem',
      channelDescription:
          'Avisos de início e fim do backup automático na nuvem.',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      idBackupResult,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> showBackupPendingLogin() async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      _backupChannelId,
      'Backup automático na nuvem',
      channelDescription:
          'Avisos de início e fim do backup automático na nuvem.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.show(
      idBackupPending,
      'Backup pendente',
      'Faça login no Vox Finance para enviar o backup na nuvem.',
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> notifyBackupAutoSafe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {}
  }
}
