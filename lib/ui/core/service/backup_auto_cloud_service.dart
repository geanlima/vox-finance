import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'package:vox_finance/bootstrap/firebase_bootstrap.dart';
import 'package:vox_finance/ui/data/service/backup/backup_manager.dart';

/// Backup automático diário na nuvem (Android) via WorkManager.
///
/// Estratégia:
/// - Agenda um ONE-OFF para o próximo horário configurado.
/// - Quando roda, faz o backup e agenda o próximo (loop diário).
class BackupAutoCloudService {
  BackupAutoCloudService._();
  static final instance = BackupAutoCloudService._();

  static const String taskName = 'backup_auto_cloud_daily';

  static const _kEnabled = 'backup_auto_enabled';
  static const _kTimeMinutes = 'backup_auto_time_minutes'; // 0..1439
  static const _kLastRunMs = 'backup_auto_last_run_ms';
  static const _kLastOk = 'backup_auto_last_ok';
  static const _kLastError = 'backup_auto_last_error';

  static const String _tzName = 'America/Sao_Paulo';
  static bool _tzReady = false;

  static void _ensureTz() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    _tzReady = true;
  }

  /// Chame no `main()` uma vez.
  static Future<void> initialize() async {
    _ensureTz();
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  /// Dispatcher do WorkManager (top-level).
  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      if (task != taskName) return true;

      try {
        await FirebaseBootstrap.ensureInitialized();
      } catch (_) {
        // Mesmo se falhar, vamos tentar ler prefs e reagendar.
      }

      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_kEnabled) ?? false;
      if (!enabled) return true;

      final minutes = prefs.getInt(_kTimeMinutes) ?? (2 * 60);
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Sempre reage nda o próximo, mesmo se não tiver usuário.
      _ensureTz();
      await _scheduleNextInternal(minutes: minutes);

      if (uid == null || uid.isEmpty) {
        await prefs.setInt(_kLastRunMs, DateTime.now().millisecondsSinceEpoch);
        await prefs.setBool(_kLastOk, false);
        await prefs.setString(_kLastError, 'Usuário não logado.');
        return true;
      }

      try {
        await BackupManager.instance.backup(userId: uid);
        await prefs.setInt(_kLastRunMs, DateTime.now().millisecondsSinceEpoch);
        await prefs.setBool(_kLastOk, true);
        await prefs.remove(_kLastError);
      } catch (e) {
        await prefs.setInt(_kLastRunMs, DateTime.now().millisecondsSinceEpoch);
        await prefs.setBool(_kLastOk, false);
        await prefs.setString(_kLastError, e.toString());
      }

      return true;
    });
  }

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kEnabled) ?? false;
  }

  Future<int?> timeMinutes() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kTimeMinutes);
  }

  Future<(DateTime? when, bool? ok, String? error)> lastRun() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(_kLastRunMs);
    final ok = p.getBool(_kLastOk);
    final err = p.getString(_kLastError);
    return (ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms), ok, err);
  }

  Future<void> setEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, enabled);
    if (!enabled) {
      await Workmanager().cancelByUniqueName(taskName);
    } else {
      final minutes = p.getInt(_kTimeMinutes) ?? (2 * 60);
      await _scheduleNextInternal(minutes: minutes);
    }
  }

  /// Define o horário diário (minutos desde 00:00) e (re)agenda.
  Future<void> setDailyTime({required int hour, required int minute}) async {
    final h = hour.clamp(0, 23);
    final m = minute.clamp(0, 59);
    final minutes = (h * 60) + m;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kTimeMinutes, minutes);

    final enabled = p.getBool(_kEnabled) ?? false;
    if (enabled) {
      await _scheduleNextInternal(minutes: minutes);
    }
  }

  static Future<void> _scheduleNextInternal({required int minutes}) async {
    // cancela o agendamento anterior e cria o próximo
    await Workmanager().cancelByUniqueName(taskName);

    _ensureTz();
    final loc = tz.getLocation(_tzName);
    final nowBr = tz.TZDateTime.now(loc);
    final targetToday = tz.TZDateTime(
      loc,
      nowBr.year,
      nowBr.month,
      nowBr.day,
    ).add(Duration(minutes: minutes));
    final nextBr =
        targetToday.isAfter(nowBr)
            ? targetToday
            : targetToday.add(const Duration(days: 1));

    // delay calculado em UTC para não depender do fuso do aparelho
    final delay =
        nextBr.toUtc().difference(DateTime.now().toUtc());

    // WorkManager aceita delays longos, mas vamos garantir mínimo 1 min.
    final safeDelay =
        delay < const Duration(minutes: 1) ? const Duration(minutes: 1) : delay;

    await Workmanager().registerOneOffTask(
      // id aleatório para evitar colisões
      'backup_auto_${DateTime.now().millisecondsSinceEpoch}',
      taskName,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      initialDelay: safeDelay,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );

    if (kDebugMode) {
      // ignore: avoid_print
      print('BackupAuto agendado (Brasília) para: $nextBr (delay: $safeDelay)');
    }
  }
}

