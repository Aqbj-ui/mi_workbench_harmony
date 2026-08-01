// 数据备份与恢复
//
// 为什么不用 iCloud：iCloud Documents / CloudKit 都需要在描述文件里带
// iCloud container entitlement，免费 Apple ID 侧载拿不到，装上去会直接闪退。
// 所以走"导出 JSON 到 App 文档目录"这条免费且稳妥的路：
// 配合 Info.plist 的 UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace，
// 老板能在 iPhone「文件」App → 我的 iPhone → 米工作台 里直接看到备份文件，
// 可以拷到电脑、发微信、传网盘；把 .json 放回这个目录就能在 App 里恢复。
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
// hide Transaction：项目里 models/transaction.dart 也有个 Transaction，先躲开
import 'package:sqflite/sqflite.dart' hide Transaction;

import 'db_service.dart';
import 'settings_service.dart';

/// 备份涉及的全部数据表（顺序 = 恢复时的写入顺序）
const List<String> kBackupTables = [
  'categories',
  'todos',
  'transactions',
  'saving_goals',
  'saving_deposits',
  'exercises',
  'weights',
  'habits',
  'habit_checks',
  'sleep',
];

/// 一个备份文件的描述
class BackupFile {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modified;

  BackupFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}

/// 恢复结果
class RestoreResult {
  final bool ok;
  final String message;
  final Map<String, int> counts; // 表名 -> 写入条数

  RestoreResult(this.ok, this.message, [this.counts = const {}]);

  int get total => counts.values.fold(0, (a, b) => a + b);
}

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  static const String kSignature = 'mi_workbench_backup';

  /// 备份存放目录：App 文档目录（iPhone「文件」App 里可见）
  Future<Directory> backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 生成完整数据快照
  Future<Map<String, dynamic>> buildSnapshot() async {
    final d = await DbService.instance.db;
    final data = <String, dynamic>{};
    for (final t in kBackupTables) {
      try {
        data[t] = await d.query(t);
      } catch (_) {
        // 某张表不存在（老版本库）时跳过，不让整个导出失败
        data[t] = <Map<String, Object?>>[];
      }
    }

    // 设置项（预算、目标、身高、各类提醒开关）
    final settings = <String, dynamic>{};
    try {
      final p = await SettingsService.instance.prefs;
      for (final k in p.getKeys()) {
        final v = p.get(k);
        if (v is bool || v is int || v is double || v is String) {
          settings[k] = v;
        } else if (v is List<String>) {
          settings[k] = v;
        }
      }
    } catch (_) {}

    int schema = 0;
    try {
      schema = await d.getVersion();
    } catch (_) {}

    return {
      'signature': kSignature,
      'app': '米工作台',
      'schema': schema,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'data': data,
    };
  }

  String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  /// 导出备份，返回生成的文件
  Future<BackupFile> export() async {
    final snap = await buildSnapshot();
    final dir = await backupDir();
    final name = '米工作台备份_${_stamp(DateTime.now())}.json';
    final f = File('${dir.path}/$name');
    // 带缩进，方便老板自己用记事本打开看
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snap),
      flush: true,
    );
    final st = await f.stat();
    return BackupFile(
      path: f.path,
      name: name,
      sizeBytes: st.size,
      modified: st.modified,
    );
  }

  /// 列出可用备份：backups/ 目录 + 文档根目录（老板从「文件」App 拖进来的）
  Future<List<BackupFile>> listBackups() async {
    final out = <BackupFile>[];
    final seen = <String>{};

    Future<void> scan(Directory dir) async {
      if (!await dir.exists()) return;
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File) continue;
        if (!e.path.toLowerCase().endsWith('.json')) continue;
        if (seen.contains(e.path)) continue;
        seen.add(e.path);
        try {
          final st = await e.stat();
          out.add(BackupFile(
            path: e.path,
            name: e.uri.pathSegments.last,
            sizeBytes: st.size,
            modified: st.modified,
          ));
        } catch (_) {}
      }
    }

    await scan(await backupDir());
    try {
      await scan(await getApplicationDocumentsDirectory());
    } catch (_) {}

    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  /// 从备份文件恢复
  /// [replace] = true 先清空现有数据再写入（完整还原）
  /// [replace] = false 只补进不存在的记录（按主键合并，现有数据不动）
  Future<RestoreResult> restore(String path, {bool replace = false}) async {
    final f = File(path);
    if (!await f.exists()) {
      return RestoreResult(false, '文件不存在');
    }

    Map<String, dynamic> snap;
    try {
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return RestoreResult(false, '文件格式不对，不是备份文件');
      }
      snap = decoded;
    } catch (e) {
      return RestoreResult(false, '文件读不出来：$e');
    }

    if (snap['signature'] != kSignature) {
      return RestoreResult(false, '这不是米工作台的备份文件');
    }
    final data = snap['data'];
    if (data is! Map) {
      return RestoreResult(false, '备份内容缺失');
    }

    final counts = <String, int>{};
    final d = await DbService.instance.db;

    try {
      await d.transaction((txn) async {
        if (replace) {
          // 倒序清空，避开引用顺序
          for (final t in kBackupTables.reversed) {
            try {
              await txn.delete(t);
            } catch (_) {}
          }
        }
        for (final t in kBackupTables) {
          final rows = data[t];
          if (rows is! List) continue;
          int n = 0;
          for (final r in rows) {
            if (r is! Map) continue;
            final row = <String, Object?>{};
            r.forEach((k, v) {
              if (k is String) row[k] = v;
            });
            if (row.isEmpty) continue;
            try {
              await txn.insert(
                t,
                row,
                conflictAlgorithm: replace
                    ? ConflictAlgorithm.replace
                    : ConflictAlgorithm.ignore,
              );
              n++;
            } catch (_) {
              // 单行失败不影响整体（比如老备份缺列）
            }
          }
          counts[t] = n;
        }
      });
    } catch (e) {
      return RestoreResult(false, '写入失败：$e');
    }

    // 设置项一并还原
    final s = snap['settings'];
    if (s is Map) {
      try {
        final p = await SettingsService.instance.prefs;
        for (final entry in s.entries) {
          final k = entry.key;
          final v = entry.value;
          if (k is! String) continue;
          if (v is bool) {
            await p.setBool(k, v);
          } else if (v is int) {
            await p.setInt(k, v);
          } else if (v is double) {
            await p.setDouble(k, v);
          } else if (v is String) {
            await p.setString(k, v);
          }
        }
      } catch (_) {}
    }

    final when = snap['exportedAt'];
    return RestoreResult(
      true,
      replace
          ? '已完整还原${when is String ? '（备份时间 ${when.substring(0, 16).replaceAll('T', ' ')}）' : ''}'
          : '已合并补入缺失记录',
      counts,
    );
  }
}
