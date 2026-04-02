import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_config.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/v2/app/di/injector.dart' as v2;
import 'package:vox_finance/v2/infrastructure/db/db_service_v2.dart';

class DbResetService {
  static Future<void> resetV1({bool reopen = true}) async {
    await DbService.instance.close();

    final dbPath = await DatabaseConfig.getDatabasePath();
    try {
      await deleteDatabase(dbPath);
    } catch (e) {
      debugPrint('resetV1 deleteDatabase error: $e');
    }

    if (reopen) {
      await DbService.instance.reopen();
    }
  }

  static Future<void> resetV2({bool reinitInjector = false}) async {
    try {
      await v2.InjectorV2.db.close();
    } catch (_) {}

    await DbServiceV2.resetDatabase();

    if (reinitInjector) {
      await v2.InjectorV2.init();
    }
  }
}

