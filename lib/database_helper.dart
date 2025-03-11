import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat_history.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id INTEGER,
        user_id TEXT,
        message TEXT,
        timestamp INTEGER,
        is_user BOOLEAN,
      )
    ''');
  }

  Future<int> insertMessage(int chatId, String userId, String message, bool isUser) async {
    final db = await database;
    final data = {
      'chat_id': chatId,
      'user_id': userId,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'is_user': isUser ? 1 : 0,
    };
    return await db.insert('chat_messages', data);
  }

  Future<List<Map<String, dynamic>>> getMessagesForChat(int chatId) async {
    final db = await database;
    return await db.query(
      'chat_messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<void> deleteChat(int chatId) async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );
  }
  Future<List<int>> getAllChatIds() async {
    final db = await database;
    final result = await db.rawQuery('SELECT DISTINCT chat_id FROM chat_messages');
    return result.map((row) => row['chat_id'] as int).toList();
  }
}