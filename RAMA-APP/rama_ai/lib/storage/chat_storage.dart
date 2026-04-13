import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

// ─── Data models ──────────────────────────────────────────────────────────────

class Conversation {
  final int?   id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'title':      title,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory Conversation.fromMap(Map<String, dynamic> m) => Conversation(
    id:        m['id'] as int?,
    title:     m['title'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
  );
}

class StoredMessage {
  final int?   id;
  final int    conversationId;
  final String role; // 'user' | 'ai' | 'error'
  final String text;
  final DateTime time;

  StoredMessage({
    this.id,
    required this.conversationId,
    required this.role,
    required this.text,
    required this.time,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'conversation_id': conversationId,
    'role':            role,
    'text':            text,
    'time':            time.millisecondsSinceEpoch,
  };

  factory StoredMessage.fromMap(Map<String, dynamic> m) => StoredMessage(
    id:             m['id'] as int?,
    conversationId: m['conversation_id'] as int,
    role:           m['role'] as String,
    text:           m['text'] as String,
    time:           DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
  );
}

// ─── Chat Storage Service ──────────────────────────────────────────────────────

class ChatStorage {
  static Database? _db;

  static Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path   = p.join(dbPath, 'rama_ai_chats.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            title      TEXT    NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id INTEGER NOT NULL,
            role            TEXT    NOT NULL,
            text            TEXT    NOT NULL,
            time            INTEGER NOT NULL,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // ── Conversations ─────────────────────────────────────────────────────────────

  /// Create a new conversation with a placeholder title.
  static Future<int> createConversation({String title = 'New Chat'}) async {
    final db  = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('conversations', {
      'title':      title,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Update conversation title (called after first AI reply).
  static Future<void> updateTitle(int id, String title) async {
    final db = await _database;
    await db.update(
      'conversations',
      {'title': title, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Touch the updated_at timestamp.
  static Future<void> touchConversation(int id) async {
    final db = await _database;
    await db.update(
      'conversations',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// List all conversations, newest first.
  static Future<List<Conversation>> listConversations() async {
    final db   = await _database;
    final rows = await db.query('conversations', orderBy: 'updated_at DESC');
    return rows.map(Conversation.fromMap).toList();
  }

  /// Delete a conversation and all its messages (via ON DELETE CASCADE).
  static Future<void> deleteConversation(int id) async {
    final db = await _database;
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  // ── Messages ──────────────────────────────────────────────────────────────────

  /// Append a message to a conversation.
  static Future<int> insertMessage(StoredMessage msg) async {
    final db = await _database;
    final id = await db.insert('messages', msg.toMap());
    await touchConversation(msg.conversationId);
    return id;
  }

  /// Load all messages for a conversation, oldest first.
  static Future<List<StoredMessage>> loadMessages(int conversationId) async {
    final db   = await _database;
    final rows = await db.query(
      'messages',
      where:    'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy:  'time ASC',
    );
    return rows.map(StoredMessage.fromMap).toList();
  }

  /// Last N messages for context injection.
  static Future<List<StoredMessage>> lastMessages(
      int conversationId, int n) async {
    final db   = await _database;
    final rows = await db.query(
      'messages',
      where:    'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy:  'time DESC',
      limit:    n,
    );
    return rows.map(StoredMessage.fromMap).toList().reversed.toList();
  }
}
