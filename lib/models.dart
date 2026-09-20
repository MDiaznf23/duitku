import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

String newEntryId() => const Uuid().v4().substring(0, 8);

class Account {
  String id;
  String label;
  String type; // 'cash' | 'bank' | 'ewallet' | 'other'
  double balance;
  bool isSavings;

  Account({
    String? id,
    required this.label,
    this.type = 'cash',
    this.balance = 0,
    this.isSavings = false,
  }) : id = id ?? newEntryId();

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        label: j['label'] as String,
        type: j['type'] as String? ?? 'cash',
        balance: (j['balance'] as num).toDouble(),
        isSavings: j['is_savings'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type,
        'balance': balance,
        'is_savings': isSavings,
      };
}

const Map<String, String> accountTypeLabels = {
  'cash': 'Tunai',
  'bank': 'm-Banking',
  'ewallet': 'e-Wallet',
  'other': 'Lainnya',
};

/// ─────────────────────────────────────────────────────────────
/// Satu pos alokasi / operasional (mis. Makan, Jajan, Transport)
/// ─────────────────────────────────────────────────────────────
class AllocItem {
  String id;
  String label;
  double amount;
  String freq; // 'daily' | 'period' | 'biweekly'
  List<int>? days; // 0=Senin ... 6=Minggu. null/kosong = tiap hari
  int freqCount; // untuk freq == 'period'
  int biweeklyWeeks; // untuk freq == 'biweekly'
  List<int> biweeklyDays;
  String? biweeklyAnchor;
  bool priority; // hanya dipakai mode employed
  bool variableAmount; // true = harga fluktuatif, minta input jumlah real saat dicentang
  List<double> recentAmounts; // 3 nilai real terakhir (khusus variableAmount), untuk deteksi tren naik

  AllocItem({
    required this.id,
    required this.label,
    required this.amount,
    this.freq = 'daily',
    this.days,
    this.freqCount = 1,
    this.biweeklyWeeks = 2,
    this.biweeklyDays = const [4],
    this.biweeklyAnchor,
    this.priority = false,
    this.variableAmount = false,
    List<double>? recentAmounts,
  }) : recentAmounts = recentAmounts ?? [];

  factory AllocItem.fromJson(Map<String, dynamic> j) => AllocItem(
        id: j['id'] as String,
        label: j['label'] as String,
        amount: (j['amount'] as num).toDouble(),
        freq: (j['freq'] as String?) ?? 'daily',
        days: j['days'] != null ? List<int>.from(j['days'] as List) : null,
        freqCount: (j['freq_count'] as num?)?.toInt() ?? 1,
        biweeklyWeeks: (j['biweekly_weeks'] as num?)?.toInt() ?? 2,
        biweeklyDays: j['biweekly_days'] != null
            ? List<int>.from(j['biweekly_days'] as List)
            : [4],
        biweeklyAnchor: j['biweekly_anchor'] as String?,
        priority: j['priority'] as bool? ?? false,
        variableAmount: j['variable_amount'] as bool? ?? false,
        recentAmounts: j['recent_amounts'] != null
            ? List<double>.from(
                (j['recent_amounts'] as List).map((e) => (e as num).toDouble()))
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        'freq': freq,
        if (days != null) 'days': days,
        'freq_count': freqCount,
        'biweekly_weeks': biweeklyWeeks,
        'biweekly_days': biweeklyDays,
        'biweekly_anchor': biweeklyAnchor,
        'priority': priority,
        'variable_amount': variableAmount,
        'recent_amounts': recentAmounts,
      };

  AllocItem copyWith() => AllocItem.fromJson(toJson());
}

class HistoryEntry {
  String id;
  String date;
  String type; // 'income' | 'expense'
  String note;
  double amount;
  String? itemId; // id pos operasional, null kalau input manual
  String? accountId;
  String? toAccountId;
  String kind;
  bool locked; // entri pembukuan hasil migrasi 

  HistoryEntry({
    String? id,
    required this.date,
    required this.type,
    required this.note,
    required this.amount,
    this.itemId,
    this.accountId,
    this.toAccountId,
    this.kind = 'normal',
    this.locked = false,
  }) : id = id ?? newEntryId();

  bool get isTransfer => kind == 'transfer';

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String?,
        date: j['date'] as String,
        type: j['type'] as String,
        note: j['note'] as String,
        amount: (j['amount'] as num).toDouble(),
        itemId: j['item_id'] as String?,
        accountId: j['account_id'] as String?,
        toAccountId: j['to_account_id'] as String?,
        kind: j['kind'] as String? ?? 'normal',
        locked: j['locked'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'type': type,
        'note': note,
        'amount': amount,
        'item_id': itemId,
        'account_id': accountId,
        'to_account_id': toAccountId,
        'kind': kind,
        'locked': locked,
      };
}

class UnemployedData {
  double totalBalance;
  List<AllocItem> dailyAllocations;
  List<HistoryEntry> history;

  UnemployedData({
    this.totalBalance = 0,
    List<AllocItem>? dailyAllocations,
    List<HistoryEntry>? history,
  })  : dailyAllocations = dailyAllocations ?? [],
        history = history ?? [];

  factory UnemployedData.fromJson(Map<String, dynamic> j) => UnemployedData(
        totalBalance: (j['total_balance'] as num).toDouble(),
        dailyAllocations: (j['daily_allocations'] as List)
            .map((e) => AllocItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: (j['history'] as List)
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'total_balance': totalBalance,
        'daily_allocations': dailyAllocations.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
      };
}

class EmployedData {
  double salary;
  int salaryPeriodDays;
  String? lastSalaryDate;
  double savingsPercent;
  List<Account> accounts;
  List<AllocItem> operationals;
  List<HistoryEntry> history;

  EmployedData({
    this.salary = 0,
    this.salaryPeriodDays = 30,
    this.lastSalaryDate,
    this.savingsPercent = 20,
    List<Account>? accounts,
    List<AllocItem>? operationals,
    List<HistoryEntry>? history,
  })  : accounts = accounts ??
            [
              Account(id: 'tunai', label: 'Tunai', type: 'cash'),
              Account(id: 'tabungan', label: 'Tabungan', type: 'bank', isSavings: true),
            ],
        operationals = operationals ?? [],
        history = history ?? [];

  double get totalBalance =>
      accounts.where((a) => !a.isSavings).fold(0.0, (s, a) => s + a.balance);

  double get savingsBalance =>
      accounts.where((a) => a.isSavings).fold(0.0, (s, a) => s + a.balance);

  Account get defaultAccount =>
      accounts.firstWhere((a) => !a.isSavings, orElse: () => accounts.first);

  Account get defaultSavings =>
      accounts.firstWhere((a) => a.isSavings, orElse: () => accounts.first);

  Account accountById(String? id) {
    if (id != null) {
      for (final a in accounts) {
        if (a.id == id) return a;
      }
    }
    return defaultAccount;
  }

  factory EmployedData.fromJson(Map<String, dynamic> j) {
    List<Account> accs;
    if (j['accounts'] != null) {
      accs = (j['accounts'] as List)
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // File lama (sebelum ada kantong): satu saldo, satu tabungan.
      accs = [
        Account(
            id: 'tunai',
            label: 'Tunai',
            type: 'cash',
            balance: (j['total_balance'] as num?)?.toDouble() ?? 0),
        Account(
            id: 'tabungan',
            label: 'Tabungan',
            type: 'bank',
            balance: (j['savings_balance'] as num?)?.toDouble() ?? 0,
            isSavings: true),
      ];
    }
    return EmployedData(
      salary: (j['salary'] as num).toDouble(),
      salaryPeriodDays: (j['salary_period_days'] as num?)?.toInt() ?? 30,
      lastSalaryDate: j['last_salary_date'] as String?,
      savingsPercent: (j['savings_percent'] as num?)?.toDouble() ?? 20,
      accounts: accs,
      operationals: (j['operationals'] as List)
          .map((e) => AllocItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      history: (j['history'] as List)
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'salary': salary,
        'salary_period_days': salaryPeriodDays,
        'last_salary_date': lastSalaryDate,
        'savings_percent': savingsPercent,
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'operationals': operationals.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
      };
}

class AppData {
  static const int schemaVersion = 3;

  String mode; // 'unemployed' | 'employed'
  UnemployedData unemployed;
  EmployedData employed;
  Map<String, Map<String, bool>> dailyLog;

  AppData({
    required this.mode,
    required this.unemployed,
    required this.employed,
    required this.dailyLog,
  });

  factory AppData.defaultData() => AppData(
        mode: 'unemployed',
        unemployed: UnemployedData(
          totalBalance: 0,
          dailyAllocations: [
            AllocItem(id: 'makan', label: 'Makan', amount: 30000),
            AllocItem(id: 'jajan', label: 'Jajan', amount: 10000),
            AllocItem(id: 'lainnya', label: 'Lain-lain', amount: 5000),
          ],
          history: [],
        ),
        employed: EmployedData(
          salary: 0,
          salaryPeriodDays: 30,
          lastSalaryDate: null,
          savingsPercent: 20,
          operationals: [
            AllocItem(
                id: 'transport',
                label: 'Transport',
                amount: 15000,
                priority: true),
            AllocItem(id: 'makan', label: 'Makan', amount: 30000, priority: true),
            AllocItem(id: 'jajan', label: 'Jajan', amount: 10000, priority: false),
          ],
          history: [],
        ),
        dailyLog: {},
      );

  factory AppData.fromJson(Map<String, dynamic> j) {
    final data = AppData(
      mode: j['mode'] as String? ?? 'unemployed',
      unemployed:
          UnemployedData.fromJson(j['unemployed'] as Map<String, dynamic>),
      employed: EmployedData.fromJson(j['employed'] as Map<String, dynamic>),
      dailyLog: (j['daily_log'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(
          k,
          (v as Map<String, dynamic>).map(
            (k2, v2) => MapEntry(k2, v2 as bool),
          ),
        ),
      ),
    );

    final version = (j['schema_version'] as num?)?.toInt() ?? 1;
    if (version < 2) _migrateToV2(data);
    if (version < 3) _migrateToV3(data);
    return data;
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'mode': mode,
        'unemployed': unemployed.toJson(),
        'employed': employed.toJson(),
        'daily_log': dailyLog,
      };

  static void _migrateToV2(AppData data) {
    _migrateHistory(data, data.unemployed.history,
        data.unemployed.dailyAllocations, null);
    _migrateHistory(
        data, data.employed.history, data.employed.operationals, data.employed);
  }

  static void _migrateHistory(
    AppData data,
    List<HistoryEntry> history,
    List<AllocItem> items,
    EmployedData? emp,
  ) {
    final labelToId = <String, String>{};
    for (final it in items) {
      labelToId[it.label.toLowerCase()] = it.id;
    }

    final reconcile = <int, HistoryEntry>{};

    for (var i = 0; i < history.length; i++) {
      final e = history[i];
      final note = e.note.toLowerCase();

      // 1. tebak kind
      if (e.type == 'income' && note.startsWith('gaji masuk')) {
        e.kind = 'salary';
      } else if (note.contains('set saldo manual') ||
          note.contains('reset saldo manual')) {
        e.kind = 'adjust';
      } else if (e.type == 'income' &&
          emp != null &&
          note.contains('talangan dari tabungan')) {
        e.kind = 'transfer';
      } else if (e.type == 'expense' &&
          emp != null &&
          (note.contains('tabungan') || note.contains('nabung'))) {
        // 3. PERBAIKAN: dulu saldo berkurang tapi tabungan tidak bertambah.
        e.kind = 'transfer';
        emp.defaultSavings.balance += e.amount;
      } else {
        e.kind = 'normal';
      }

      // 2. sambungkan ke pos operasional kalau memang berasal dari checklist
      if (e.kind == 'normal' && e.type == 'expense' && e.itemId == null) {
        final guessed = labelToId[note];
        if (guessed != null && data.dailyLog[e.date]?[guessed] == true) {
          e.itemId = guessed;
        }
      }

      // 4. entri pembukuan potongan tabungan untuk gaji lama
      if (e.kind == 'salary' && emp != null && emp.savingsPercent > 0) {
        final potongan = e.amount * emp.savingsPercent / 100;
        if (potongan > 0) {
          reconcile[i] = HistoryEntry(
            date: e.date,
            type: 'expense',
            note: 'Potongan tabungan',
            amount: potongan,
            kind: 'transfer',
            locked: true,
          );
        }
      }
    }

    // sisipkan dari belakang supaya index tidak bergeser
    final keys = reconcile.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final i in keys) {
      history.insert(i + 1, reconcile[i]!);
    }
  }

  static void _migrateToV3(AppData data) {
    final d = data.employed;
    final mainId = d.defaultAccount.id;
    final savId = d.defaultSavings.id;
    for (final e in d.history) {
      if (e.accountId != null) continue; 
      e.accountId = mainId;
      if (e.kind == 'transfer') e.toAccountId = savId;
    }
  }
}

/// ─────────────────────────────────────────────────────────────
/// Penyimpanan lokal — file data.json di direktori dokumen app
/// ─────────────────────────────────────────────────────────────
class Store {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/data.json');
  }

  static Future<AppData> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) {
        final d = AppData.defaultData();
        await save(d);
        return d;
      }
      final content = await f.readAsString();
      final d = AppData.fromJson(jsonDecode(content) as Map<String, dynamic>);
      await save(d);
      return d;
    } catch (_) {
      final d = AppData.defaultData();
      await save(d);
      return d;
    }
  }

  static Future<void> save(AppData data) async {
    final f = await _file();
    await f.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data.toJson()));
  }
}
