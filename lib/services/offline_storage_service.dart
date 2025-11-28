import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class OfflineStorageService {
  static final OfflineStorageService _instance = OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'metermate_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table for pending job completions
        await db.execute('''
          CREATE TABLE pending_job_completions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            job_id TEXT NOT NULL,
            completion_data TEXT NOT NULL,
            photo_paths TEXT,
            created_at INTEGER NOT NULL,
            retry_count INTEGER DEFAULT 0,
            status TEXT DEFAULT 'pending'
          )
        ''');

        // Table for pending photo uploads
        await db.execute('''
          CREATE TABLE pending_photo_uploads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            job_id TEXT NOT NULL,
            photo_path TEXT NOT NULL,
            photo_type TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            retry_count INTEGER DEFAULT 0,
            status TEXT DEFAULT 'pending'
          )
        ''');

        // Indexes for better performance
        await db.execute('CREATE INDEX idx_job_id ON pending_job_completions(job_id)');
        await db.execute('CREATE INDEX idx_status ON pending_job_completions(status)');
        await db.execute('CREATE INDEX idx_photo_status ON pending_photo_uploads(status)');
      },
    );
  }

  // Save pending job completion
  Future<int> savePendingJobCompletion({
    required String jobId,
    required Map<String, dynamic> completionData,
    List<String>? photoPaths,
  }) async {
    final db = await database;
    return await db.insert(
      'pending_job_completions',
      {
        'job_id': jobId,
        'completion_data': jsonEncode(completionData),
        'photo_paths': photoPaths != null ? jsonEncode(photoPaths) : null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'retry_count': 0,
        'status': 'pending',
      },
    );
  }

  // Get all pending job completions
  Future<List<Map<String, dynamic>>> getPendingJobCompletions() async {
    final db = await database;
    final results = await db.query(
      'pending_job_completions',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );

    return results.map((row) {
      return {
        'id': row['id'],
        'job_id': row['job_id'],
        'completion_data': jsonDecode(row['completion_data'] as String),
        'photo_paths': row['photo_paths'] != null
            ? List<String>.from(jsonDecode(row['photo_paths'] as String))
            : null,
        'created_at': row['created_at'],
        'retry_count': row['retry_count'],
      };
    }).toList();
  }

  // Mark job completion as synced
  Future<void> markJobCompletionSynced(int id) async {
    final db = await database;
    await db.update(
      'pending_job_completions',
      {'status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Mark job completion as failed
  Future<void> markJobCompletionFailed(int id, {int? retryCount}) async {
    final db = await database;
    await db.update(
      'pending_job_completions',
      {
        'status': 'failed',
        'retry_count': retryCount ?? 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Increment retry count
  Future<void> incrementRetryCount(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_job_completions SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  // Delete synced records older than 7 days
  Future<void> cleanupOldRecords() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    await db.delete(
      'pending_job_completions',
      where: 'status = ? AND created_at < ?',
      whereArgs: ['synced', sevenDaysAgo],
    );
    await db.delete(
      'pending_photo_uploads',
      where: 'status = ? AND created_at < ?',
      whereArgs: ['synced', sevenDaysAgo],
    );
  }

  // Get count of pending items
  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_job_completions WHERE status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

