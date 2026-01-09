import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:vox_finance/ui/data/service/backup/google_auth_client.dart';

import '../../database/database_backup_service.dart';
import '../db_service.dart';
import 'backup_provider.dart';

class GoogleDriveBackupService implements BackupProvider {
  GoogleDriveBackupService._();
  static final instance = GoogleDriveBackupService._();

  static const _fileName = 'vox_finance_backup.db';

  @override
  String get key => 'google_drive';

  @override
  String get nome => 'Google Drive';

  final GoogleSignIn _signIn = GoogleSignIn(
    scopes: const [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  Future<drive.DriveApi> _api() async {
    final acc = await _signIn.signInSilently() ?? await _signIn.signIn();
    if (acc == null) {
      throw Exception('Login Google cancelado');
    }

    final headers = await acc.authHeaders;
    return drive.DriveApi(GoogleAuthClient(headers));
  }

  Future<drive.File?> _findFile(drive.DriveApi api) async {
    final res = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$_fileName' and trashed=false",
      pageSize: 1,
      $fields: 'files(id,name,modifiedTime)',
    );

    final files = res.files ?? [];
    return files.isEmpty ? null : files.first;
  }

  @override
  Future<void> backupTudo({required String userId}) async {
    final backup = await DatabaseBackupService.criarBackup();
    if (backup == null) return;

    final api = await _api();
    final existing = await _findFile(api);

    final media = drive.Media(backup.openRead(), await backup.length());

    if (existing == null) {
      final metaCreate =
          drive.File()
            ..name = _fileName
            ..parents = ['appDataFolder'];

      await api.files.create(metaCreate, uploadMedia: media);
    } else {
      final metaUpdate =
          drive.File()..name = _fileName; // opcional (pode até remover)

      await api.files.update(metaUpdate, existing.id!, uploadMedia: media);
    }
  }

  @override
  Future<bool> restaurarTudo({required String userId}) async {
    final api = await _api();
    final file = await _findFile(api);
    if (file == null) return false;

    await DbService.instance.close();

    final dbFile = await DatabaseBackupService.getDatabaseFile();
    final tmp = File('${dbFile.path}.tmp');

    final media = await api.files.get(
      file.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    if (media is! drive.Media) {
      await DbService.instance.reopen();
      return false;
    }

    final sink = tmp.openWrite();
    await media.stream.pipe(sink);
    await sink.close();

    if (!await tmp.exists() || await tmp.length() == 0) {
      await DbService.instance.reopen();
      return false;
    }

    if (await dbFile.exists()) {
      await dbFile.delete();
    }

    await tmp.rename(dbFile.path);
    await DbService.instance.reopen();
    return true;
  }

  @override
  Future<DateTime?> ultimaAtualizacao({required String userId}) async {
    final api = await _api();
    final file = await _findFile(api);
    return file?.modifiedTime?.toLocal();
  }
}
