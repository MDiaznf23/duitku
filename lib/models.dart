import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

/// ─────────────────────────────────────────────────────────────
/// Satu baris riwayat transaksi
/// ─────────────────────────────────────────────────────────────
class HistoryEntry {
  String date;
  String type; // 'income' | 'expense'
  String note;
  double amount;

  HistoryEntry({
    required this.date,
    required this.type,
    required this.note,
    required this.amount,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        date: j['date'] as String,
        type: j['type'] as String,
        note: j['note'] as String,
        amount: (j['amount'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() =>
      {'date': date, 'type': type, 'note': note, 'amount': amount};
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
  double totalBalance;
  double savingsBalance;
  List<AllocItem> operationals;
  List<HistoryEntry> history;

  EmployedData({
    this.salary = 0,
    this.salaryPeriodDays = 30,
    this.lastSalaryDate,
    this.savingsPercent = 20,
    this.totalBalance = 0,
    this.savingsBalance = 0,
    List<AllocItem>? operationals,
    List<HistoryEntry>? history,
  })  : operationals = operationals ?? [],
        history = history ?? [];

  factory EmployedData.fromJson(Map<String, dynamic> j) => EmployedData(
        salary: (j['salary'] as num).toDouble(),
        salaryPeriodDays: (j['salary_period_days'] as num?)?.toInt() ?? 30,
        lastSalaryDate: j['last_salary_date'] as String?,
        savingsPercent: (j['savings_percent'] as num?)?.toDouble() ?? 20,
        totalBalance: (j['total_balance'] as num).toDouble(),
        savingsBalance: (j['savings_balance'] as num?)?.toDouble() ?? 0,
        operationals: (j['operationals'] as List)
            .map((e) => AllocItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: (j['history'] as List)
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'salary': salary,
        'salary_period_days': salaryPeriodDays,
        'last_salary_date': lastSalaryDate,
        'savings_percent': savingsPercent,
        'total_balance': totalBalance,
        'savings_balance': savingsBalance,
        'operationals': operationals.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
      };
}

class AppData {
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
          totalBalance: 0,
          savingsBalance: 0,
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

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
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

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'unemployed': unemployed.toJson(),
        'employed': employed.toJson(),
        'daily_log': dailyLog,
      };
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
      return AppData.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      // Kalau file korup/format lama, mulai dari default agar app tidak crash
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
