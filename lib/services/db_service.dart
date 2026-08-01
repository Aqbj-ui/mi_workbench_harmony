// SQLite 数据库服务 - 本地存储所有数据
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/todo.dart';
import '../models/transaction.dart';
import '../models/exercise_record.dart';
import '../models/weight_record.dart';
import '../models/workbench_category.dart';
import '../models/habit.dart';
import '../models/sleep_record.dart';
import '../models/saving_goal.dart';

class DbService {
  static final DbService instance = DbService._();
  DbService._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'mi_workbench.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: (db, v) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('ALTER TABLE todos ADD COLUMN due_at INTEGER');
          await db.execute('ALTER TABLE todos ADD COLUMN tags TEXT');
          await db.execute("ALTER TABLE todos ADD COLUMN repeat TEXT NOT NULL DEFAULT 'none'");
          await db.execute('ALTER TABLE weights ADD COLUMN body_fat REAL');
          await db.execute('''
      CREATE TABLE IF NOT EXISTS habits(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        repeat_days TEXT NOT NULL DEFAULT '',
        target_streak INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS habit_checks(
              id TEXT PRIMARY KEY,
              habit_id TEXT NOT NULL,
              checked_date TEXT NOT NULL,
              note TEXT,
              UNIQUE(habit_id, checked_date)
            )
          ''');
        }
        if (oldV < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sleep(
              id TEXT PRIMARY KEY,
              date_key TEXT NOT NULL UNIQUE,
              bedtime INTEGER,
              wake_time INTEGER,
              duration_hours REAL NOT NULL,
              source TEXT NOT NULL DEFAULT 'manual',
              note TEXT
            )
          ''');
        }
        if (oldV < 4) {
          // 双账本 + 收支类型（老数据默认「个人 · 支出」）
          await db.execute(
              "ALTER TABLE transactions ADD COLUMN ledger TEXT NOT NULL DEFAULT 'personal'");
          await db.execute(
              "ALTER TABLE transactions ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'");
          await db.execute('''
            CREATE TABLE IF NOT EXISTS saving_goals(
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              icon TEXT NOT NULL DEFAULT '🎯',
              target_amount REAL NOT NULL,
              deadline INTEGER,
              created_at INTEGER NOT NULL,
              archived INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS saving_deposits(
              id TEXT PRIMARY KEY,
              goal_id TEXT NOT NULL,
              amount REAL NOT NULL,
              occurred_at INTEGER NOT NULL,
              note TEXT
            )
          ''');
        }
        if (oldV < 5) {
          // 习惯目标连续天数（老数据默认 0 = 未设目标）
          await db.execute(
              'ALTER TABLE habits ADD COLUMN target_streak INTEGER NOT NULL DEFAULT 0');
        }
        if (oldV < 6) {
          // 待办双账本 + 备注（老数据默认个人账本）
          await db.execute(
              "ALTER TABLE todos ADD COLUMN ledger TEXT NOT NULL DEFAULT 'personal'");
          await db.execute('ALTER TABLE todos ADD COLUMN note TEXT');
        }
        if (oldV < 7) {
          // 运动强度 / 距离 / 卡路里（老数据默认适中，卡路里 0 = 按 MET 自动估算）
          await db.execute(
              "ALTER TABLE exercises ADD COLUMN intensity TEXT NOT NULL DEFAULT 'medium'");
          await db.execute(
              'ALTER TABLE exercises ADD COLUMN distance_km REAL NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE exercises ADD COLUMN calories INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE todos(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        priority TEXT NOT NULL DEFAULT 'normal',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        done_at INTEGER,
        due_at INTEGER,
        tags TEXT,
        repeat TEXT NOT NULL DEFAULT 'none',
        ledger TEXT NOT NULL DEFAULT 'personal',
        note TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions(
        id TEXT PRIMARY KEY,
        raw_text TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        occurred_at INTEGER NOT NULL,
        note TEXT,
        ledger TEXT NOT NULL DEFAULT 'personal',
        type TEXT NOT NULL DEFAULT 'expense'
      )
    ''');
    await db.execute('''
      CREATE TABLE saving_goals(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT '🎯',
        target_amount REAL NOT NULL,
        deadline INTEGER,
        created_at INTEGER NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE saving_deposits(
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        amount REAL NOT NULL,
        occurred_at INTEGER NOT NULL,
        note TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE exercises(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        performed_at INTEGER NOT NULL,
        note TEXT,
        intensity TEXT NOT NULL DEFAULT 'medium',
        distance_km REAL NOT NULL DEFAULT 0,
        calories INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE weights(
        id TEXT PRIMARY KEY,
        weight_kg REAL NOT NULL,
        measured_at INTEGER NOT NULL,
        note TEXT,
        body_fat REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE categories(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE habits(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        repeat_days TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE habit_checks(
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        checked_date TEXT NOT NULL,
        note TEXT,
        UNIQUE(habit_id, checked_date)
      )
    ''');
    await db.execute('''
      CREATE TABLE sleep(
        id TEXT PRIMARY KEY,
        date_key TEXT NOT NULL UNIQUE,
        bedtime INTEGER,
        wake_time INTEGER,
        duration_hours REAL NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        note TEXT
      )
    ''');
    // 插入默认分类（参照设计稿）
    final defaults = [
      ['daily', '每日计划', '📅'],
      ['diet', '减肥', '🥗'],
      ['english', '英语', '🔤'],
      ['ai', 'AI学习', '🤖'],
      ['exercise', '运动', '🏃'],
      ['beauty', '妆容', '💄'],
      ['reading', '读书', '📚'],
      ['report', '每日学习汇报', '📝'],
      ['vacation', '休假', '🌸'],
      ['mood', '心情日记', '💛'],
      ['review', '复盘', '🔍'],
    ];
    for (var i = 0; i < defaults.length; i++) {
      await db.insert('categories', {
        'id': defaults[i][0],
        'name': defaults[i][1],
        'icon': defaults[i][2],
        'sort_order': i,
      });
    }
  }

  // ============ Todo ============
  Future<List<Todo>> getTodos() async {
    final d = await db;
    final rows = await d.query('todos', orderBy: 'sort_order ASC, created_at DESC');
    return rows.map(Todo.fromMap).toList();
  }

  Future<void> insertTodo(Todo t) async => (await db).insert('todos', t.toMap());
  /// 批量插入（模板一键添加）
  Future<void> insertTodos(List<Todo> list) async {
    final d = await db;
    final batch = d.batch();
    for (final t in list) {
      batch.insert('todos', t.toMap());
    }
    await batch.commit(noResult: true);
  }
  Future<void> updateTodo(Todo t) async =>
      (await db).update('todos', t.toMap(), where: 'id=?', whereArgs: [t.id]);
  Future<void> deleteTodo(String id) async =>
      (await db).delete('todos', where: 'id=?', whereArgs: [id]);
  Future<void> reorderTodos(List<Todo> todos) async {
    final d = await db;
    final batch = d.batch();
    for (var i = 0; i < todos.length; i++) {
      batch.update('todos', {'sort_order': i}, where: 'id=?', whereArgs: [todos[i].id]);
    }
    await batch.commit(noResult: true);
  }

  // ============ Transaction ============
  /// [ledger] 传 null = 全部账本；[type] 传 null = 收支都要
  Future<List<Transaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    String? ledger,
    String? type,
  }) async {
    final d = await db;
    final where = StringBuffer('1=1');
    final args = <Object?>[];
    if (from != null) { where.write(' AND occurred_at >= ?'); args.add(from.millisecondsSinceEpoch); }
    if (to != null) { where.write(' AND occurred_at <= ?'); args.add(to.millisecondsSinceEpoch); }
    if (ledger != null) { where.write(' AND ledger = ?'); args.add(ledger); }
    if (type != null) { where.write(' AND type = ?'); args.add(type); }
    final rows = await d.query('transactions', where: where.toString(), whereArgs: args, orderBy: 'occurred_at DESC');
    return rows.map(Transaction.fromMap).toList();
  }

  Future<void> insertTransaction(Transaction t) async =>
      (await db).insert('transactions', t.toMap());
  Future<void> updateTransaction(Transaction t) async =>
      (await db).update('transactions', t.toMap(), where: 'id=?', whereArgs: [t.id]);
  Future<void> deleteTransaction(String id) async =>
      (await db).delete('transactions', where: 'id=?', whereArgs: [id]);

  /// 分类汇总（默认只统计支出）
  Future<Map<String, double>> getCategorySum({
    DateTime? from,
    DateTime? to,
    String? ledger,
    String type = TxType.expense,
  }) async {
    final list = await getTransactions(from: from, to: to, ledger: ledger, type: type);
    final map = <String, double>{};
    for (final t in list) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  /// 收入 / 支出 / 结余 汇总
  Future<({double income, double expense, double balance})> getSummary({
    DateTime? from,
    DateTime? to,
    String? ledger,
  }) async {
    final list = await getTransactions(from: from, to: to, ledger: ledger);
    double income = 0, expense = 0;
    for (final t in list) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return (income: income, expense: expense, balance: income - expense);
  }

  // ============ Saving（存钱计划） ============
  Future<List<SavingGoal>> getSavingGoals({bool includeArchived = false}) async {
    final d = await db;
    final rows = await d.query(
      'saving_goals',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(SavingGoal.fromMap).toList();
  }

  Future<void> insertSavingGoal(SavingGoal g) async =>
      (await db).insert('saving_goals', g.toMap());
  Future<void> updateSavingGoal(SavingGoal g) async =>
      (await db).update('saving_goals', g.toMap(), where: 'id=?', whereArgs: [g.id]);

  Future<void> deleteSavingGoal(String id) async {
    final d = await db;
    await d.delete('saving_deposits', where: 'goal_id=?', whereArgs: [id]);
    await d.delete('saving_goals', where: 'id=?', whereArgs: [id]);
  }

  Future<List<SavingDeposit>> getDeposits({String? goalId}) async {
    final d = await db;
    final rows = await d.query(
      'saving_deposits',
      where: goalId == null ? null : 'goal_id=?',
      whereArgs: goalId == null ? null : [goalId],
      orderBy: 'occurred_at DESC',
    );
    return rows.map(SavingDeposit.fromMap).toList();
  }

  Future<void> insertDeposit(SavingDeposit s) async =>
      (await db).insert('saving_deposits', s.toMap());
  Future<void> deleteDeposit(String id) async =>
      (await db).delete('saving_deposits', where: 'id=?', whereArgs: [id]);

  /// 每个目标已存金额 { goalId: saved }
  Future<Map<String, double>> getSavedAmounts() async {
    final list = await getDeposits();
    final map = <String, double>{};
    for (final s in list) {
      map[s.goalId] = (map[s.goalId] ?? 0) + s.amount;
    }
    return map;
  }

  /// 全部目标累计已存（首页用）
  Future<double> getTotalSaved() async {
    final list = await getDeposits();
    double total = 0;
    for (final s in list) {
      total += s.amount;
    }
    return total;
  }

  // ============ Exercise ============
  Future<List<ExerciseRecord>> getExercises({DateTime? from, DateTime? to}) async {
    final d = await db;
    final where = StringBuffer('1=1');
    final args = <Object?>[];
    if (from != null) { where.write(' AND performed_at >= ?'); args.add(from.millisecondsSinceEpoch); }
    if (to != null) { where.write(' AND performed_at <= ?'); args.add(to.millisecondsSinceEpoch); }
    final rows = await d.query('exercises', where: where.toString(), whereArgs: args, orderBy: 'performed_at DESC');
    return rows.map(ExerciseRecord.fromMap).toList();
  }
  Future<void> insertExercise(ExerciseRecord e) async =>
      (await db).insert('exercises', e.toMap());
  Future<void> updateExercise(ExerciseRecord e) async => (await db)
      .update('exercises', e.toMap(), where: 'id=?', whereArgs: [e.id]);
  Future<void> deleteExercise(String id) async =>
      (await db).delete('exercises', where: 'id=?', whereArgs: [id]);

  // ============ Weight ============
  Future<List<WeightRecord>> getWeights() async {
    final rows = await (await db).query('weights', orderBy: 'measured_at ASC');
    return rows.map(WeightRecord.fromMap).toList();
  }
  Future<void> insertWeight(WeightRecord w) async =>
      (await db).insert('weights', w.toMap());
  Future<void> deleteWeight(String id) async =>
      (await db).delete('weights', where: 'id=?', whereArgs: [id]);

  // ============ Sleep ============
  Future<SleepRecord?> getSleepByDate(String dateKey) async {
    final rows = await (await db).query('sleep',
        where: 'date_key=?', whereArgs: [dateKey], limit: 1);
    if (rows.isEmpty) return null;
    return SleepRecord.fromMap(rows.first);
  }

  // 按日期保存（同一天覆盖）
  Future<void> saveSleep(SleepRecord s) async {
    final d = await db;
    final existing = await getSleepByDate(s.dateKey);
    if (existing != null) {
      final merged = SleepRecord(
        id: existing.id,
        date: s.date,
        bedtime: s.bedtime,
        wakeTime: s.wakeTime,
        durationHours: s.durationHours,
        source: s.source,
        note: s.note,
      );
      await d.update('sleep', merged.toMap(), where: 'id=?', whereArgs: [existing.id]);
    } else {
      await d.insert('sleep', s.toMap());
    }
  }

  Future<List<SleepRecord>> getSleepRange(DateTime from, DateTime to) async {
    final a = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final b = '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';
    final rows = await (await db).query('sleep',
        where: 'date_key >= ? AND date_key <= ?', whereArgs: [a, b], orderBy: 'date_key ASC');
    return rows.map(SleepRecord.fromMap).toList();
  }

  Future<void> deleteSleep(String id) async =>
      (await db).delete('sleep', where: 'id=?', whereArgs: [id]);

  // ============ Categories ============
  Future<List<WorkbenchCategory>> getCategories() async {
    final rows = await (await db).query('categories', orderBy: 'sort_order ASC');
    return rows.map(WorkbenchCategory.fromMap).toList();
  }
  Future<void> insertCategory(WorkbenchCategory c) async =>
      (await db).insert('categories', c.toMap());
  Future<void> deleteCategory(String id) async =>
      (await db).delete('categories', where: 'id=?', whereArgs: [id]);

  // ============ Habits ============
  Future<List<Habit>> getHabits() async {
    final rows = await (await db).query('habits', orderBy: 'created_at ASC');
    return rows.map(Habit.fromMap).toList();
  }
  Future<void> insertHabit(Habit h) async => (await db).insert('habits', h.toMap());
  Future<void> updateHabit(Habit h) async => (await db).update('habits', h.toMap(),
      where: 'id=?', whereArgs: [h.id]);
  Future<void> deleteHabit(String id) async {
    final d = await db;
    await d.delete('habit_checks', where: 'habit_id=?', whereArgs: [id]);
    await d.delete('habits', where: 'id=?', whereArgs: [id]);
  }
  Future<List<HabitCheck>> getChecks({String? habitId, String? date}) async {
    final d = await db;
    final where = StringBuffer('1=1');
    final args = <Object?>[];
    if (habitId != null) { where.write(' AND habit_id = ?'); args.add(habitId); }
    if (date != null) { where.write(' AND checked_date = ?'); args.add(date); }
    final rows = await d.query('habit_checks', where: where.toString(), whereArgs: args);
    return rows.map(HabitCheck.fromMap).toList();
  }
  Future<void> checkHabit(String habitId, String date, [String? note]) async {
    final d = await db;
    await d.insert('habit_checks', HabitCheck(
      id: '$habitId-$date',
      habitId: habitId,
      date: date,
      note: note,
    ).toMap());
  }
  Future<void> uncheckHabit(String habitId, String date) async {
    await (await db).delete('habit_checks',
        where: 'habit_id=? AND checked_date=?', whereArgs: [habitId, date]);
  }
}
