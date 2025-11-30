// ignore_for_file: unused_local_variable, unused_catch_stack, empty_catches, unused_element

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';

class DbService {
  DbService._internal();
  static final DbService instance = DbService._internal();

  factory DbService() => instance;

  Database? _db;

  // ============================================================
  //  A C E S S O   A O   B A N C O
  // ============================================================

  Future<Database> get db async {
    _db ??= await DatabaseInitializer.initialize();
    return _db!;
  }
}
