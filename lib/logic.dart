import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'models.dart';

/// ─────────────────────────────────────────────────────────────
/// Helper umum
/// ─────────────────────────────────────────────────────────────

String fmt(num amount) {
  final isNeg = amount < 0;
  final intAmt = amount.abs().round();
  final str = intAmt.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
    buffer.write(str[i]);
  }
  return '${isNeg ? "-" : ""}Rp $buffer';
}

final DateFormat _isoFmt = DateFormat('yyyy-MM-dd');

String todayStr() => _isoFmt.format(DateTime.now());

String isoDate(DateTime d) => _isoFmt.format(d);

DateTime parseIso(String s) => DateTime.parse(s);

/// Python: date.weekday() -> Senin=0 ... Minggu=6
/// Dart:   DateTime.weekday -> Senin=1 ... Minggu=7
int pythonWeekday(DateTime d) => (d.weekday - 1) % 7;

List<HistoryEntry> historyOf(AppData data, [String? mode]) =>
    (mode ?? data.mode) == 'unemployed'
        ? data.unemployed.history
        : data.employed.history;

double balanceOf(AppData data, [String? mode]) =>
    (mode ?? data.mode) == 'unemployed'
        ? data.unemployed.totalBalance
        : data.employed.totalBalance;

Account _resolveAccount(EmployedData d, String? accountId) {
  if (accountId != null) {
    for (final a in d.accounts) {
      if (a.id == accountId) return a;
    }
  }
  return d.defaultAccount;
}

Account _resolveSavings(EmployedData d, String? accountId) {
  if (accountId != null) {
    for (final a in d.accounts) {
      if (a.id == accountId) return a;
    }
  }
  return d.defaultSavings;
}

void _addToBalance(AppData data, double delta, [String? mode, String? accountId]) {
  final m = mode ?? data.mode;
  if (m == 'unemployed') {
    data.unemployed.totalBalance += delta;
  } else {
    _resolveAccount(data.employed, accountId).balance += delta;
  }
}

/// Uang masuk ke satu kantong.
HistoryEntry addIncome(
  AppData data, {
  required double amount,
  required String note,
  String kind = 'normal',
  String? date,
  String? mode,
  String? accountId,
}) {
  final m = mode ?? data.mode;
  final resolvedAcc = m == 'unemployed' ? null : _resolveAccount(data.employed, accountId).id;
  final e = HistoryEntry(
    date: date ?? todayStr(),
    type: 'income',
    note: note,
    amount: amount,
    kind: kind,
    accountId: resolvedAcc,
  );
  _addToBalance(data, amount, m, resolvedAcc);
  historyOf(data, m).add(e);
  return e;
}

/// Uang keluar dari satu kantong.
HistoryEntry addExpense(
  AppData data, {
  required double amount,
  required String note,
  String? itemId,
  String kind = 'normal',
  String? date,
  String? mode,
  String? accountId,
}) {
  final m = mode ?? data.mode;
  final resolvedAcc = m == 'unemployed' ? null : _resolveAccount(data.employed, accountId).id;
  final e = HistoryEntry(
    date: date ?? todayStr(),
    type: 'expense',
    note: note,
    amount: amount,
    itemId: itemId,
    kind: kind,
    accountId: resolvedAcc,
  );
  _addToBalance(data, -amount, m, resolvedAcc);
  historyOf(data, m).add(e);
  return e;
}

void addSalary(AppData data, double amount, {String? accountId}) {
  final d = data.employed;
  final potongan = amount * d.savingsPercent / 100;
  d.salary = amount;
  d.lastSalaryDate = todayStr();
  addIncome(data, amount: amount, note: 'Gaji masuk', kind: 'salary', accountId: accountId);
  if (potongan > 0) {
    transferToSavings(data, amount: potongan, note: 'Potongan tabungan', fromAccountId: accountId);
  }
}

HistoryEntry transferBetweenAccounts(
  AppData data, {
  required String fromAccountId,
  required String toAccountId,
  required double amount,
  String note = 'Pindah kantong',
}) {
  final d = data.employed;
  final from = _resolveAccount(d, fromAccountId);
  final to = _resolveAccount(d, toAccountId);
  final e = HistoryEntry(
    date: todayStr(),
    type: 'expense',
    note: note,
    amount: amount,
    kind: 'transfer',
    accountId: from.id,
    toAccountId: to.id,
  );
  from.balance -= amount;
  to.balance += amount;
  d.history.add(e);
  return e;
}

/// Pindahkan uang dari satu kantong ke tabungan.
HistoryEntry transferToSavings(
  AppData data, {
  required double amount,
  String note = 'Pindah ke tabungan',
  String? fromAccountId,
  String? toSavingsAccountId,
}) {
  final d = data.employed;
  final from = _resolveAccount(d, fromAccountId);
  final to = _resolveSavings(d, toSavingsAccountId);
  final e = HistoryEntry(
    date: todayStr(),
    type: 'expense',
    note: note,
    amount: amount,
    kind: 'transfer',
    accountId: from.id,
    toAccountId: to.id,
  );
  from.balance -= amount;
  to.balance += amount;
  d.history.add(e);
  return e;
}

/// Tarik uang dari tabungan ke satu kantong (talangan / ambil tabungan).
HistoryEntry withdrawFromSavings(
  AppData data, {
  required double amount,
  String note = 'Ambil dari tabungan',
  String? toAccountId,
  String? fromSavingsAccountId,
}) {
  final d = data.employed;
  final to = _resolveAccount(d, toAccountId);
  final from = _resolveSavings(d, fromSavingsAccountId);
  final e = HistoryEntry(
    date: todayStr(),
    type: 'income',
    note: note,
    amount: amount,
    kind: 'transfer',
    accountId: to.id,
    toAccountId: from.id,
  );
  from.balance -= amount;
  to.balance += amount;
  d.history.add(e);
  return e;
}

void setBalanceManual(AppData data, double newBalance, {String? mode, String? accountId}) {
  final m = mode ?? data.mode;
  final resolvedAcc = m == 'unemployed' ? null : _resolveAccount(data.employed, accountId).id;
  final current = m == 'unemployed'
      ? data.unemployed.totalBalance
      : data.employed.accountById(resolvedAcc).balance;
  final selisih = newBalance - current;
  _addToBalance(data, selisih, m, resolvedAcc);
  historyOf(data, m).add(HistoryEntry(
    date: todayStr(),
    type: selisih >= 0 ? 'income' : 'expense',
    note: 'Set saldo manual',
    amount: selisih.abs(),
    kind: 'adjust',
    accountId: resolvedAcc,
  ));
}

/// ─────────────────────────────────────────────────────────────
/// HAPUS SATU TRANSAKSI
/// ─────────────────────────────────────────────────────────────
class DeleteResult {
  final bool ok;
  final String? reason;
  const DeleteResult(this.ok, [this.reason]);
}

/// Hapus satu entri riwayat berdasarkan id, 
DeleteResult deleteEntry(AppData data, String entryId, [String? mode]) {
  final m = mode ?? data.mode;
  final hist = historyOf(data, m);
  final idx = hist.indexWhere((h) => h.id == entryId);
  if (idx == -1) return const DeleteResult(false, 'Transaksi tidak ditemukan.');

  final e = hist[idx];

  if (e.locked) {
    return const DeleteResult(false,
        'Baris ini entri pembukuan otomatis dan tidak bisa dihapus sendiri. '
        'Hapus entri gaji induknya kalau memang mau dibatalkan.');
  }
  if (e.kind == 'adjust') {
    return const DeleteResult(false,
        'Set saldo manual tidak bisa dihapus, karena saldo sesudahnya sudah '
        'dipakai transaksi lain. Kalau angkanya salah, set saldo manual lagi '
        'dengan angka yang benar.');
  }

  // 1. balik efeknya ke saldo
  if (e.kind == 'transfer') {
    final d = data.employed;
    final accAcc = d.accountById(e.accountId);
    final toAcc = d.accountById(e.toAccountId);
    if (e.type == 'expense') {
      // accountId kehilangan, toAccountId menerima -> dibalik
      accAcc.balance += e.amount;
      toAcc.balance -= e.amount;
    } else {
      // accountId menerima, toAccountId kehilangan -> dibalik
      accAcc.balance -= e.amount;
      toAcc.balance += e.amount;
    }
  } else if (e.type == 'income') {
    _addToBalance(data, -e.amount, m, e.accountId);
  } else {
    _addToBalance(data, e.amount, m, e.accountId);
  }

  // 2. lepas centang checklist kalau entri ini berasal dari pos
  if (e.itemId != null) {
    final log = data.dailyLog[e.date];
    if (log != null) log[e.itemId!] = false;

    final items = m == 'unemployed'
        ? data.unemployed.dailyAllocations
        : data.employed.operationals;
    for (final it in items) {
      if (it.id == e.itemId &&
          it.variableAmount &&
          it.recentAmounts.isNotEmpty &&
          it.recentAmounts.last == e.amount) {
        it.recentAmounts.removeLast();
        break;
      }
    }
  }

  hist.removeAt(idx);

  // 3. kalau yang dihapus adalah gaji, ikut hapus potongan tabungannya
  //    dan mundurkan tanggal gajian ke entri gaji sebelumnya
  if (e.kind == 'salary') {
    final pair = hist.indexWhere((h) =>
        h.kind == 'transfer' &&
        h.type == 'expense' &&
        h.date == e.date &&
        h.note.toLowerCase().startsWith('potongan tabungan'));
    if (pair != -1) {
      final p = hist[pair];
      final accAcc = data.employed.accountById(p.accountId);
      final toAcc = data.employed.accountById(p.toAccountId);
      accAcc.balance += p.amount;
      toAcc.balance -= p.amount;
      hist.removeAt(pair);
    }
    final prevSalary =
        hist.where((h) => h.kind == 'salary').map((h) => h.date).toList()
          ..sort();
    data.employed.lastSalaryDate =
        prevSalary.isEmpty ? null : prevSalary.last;
  }

  return const DeleteResult(true);
}

/// ─────────────────────────────────────────────────────────────
/// Apakah pos aktif hari ini — MODE PENGANGGURAN
/// ─────────────────────────────────────────────────────────────
bool opActiveTodayUnemployed(AppData data, AllocItem op) {
  final today = DateTime.now();
  final todayWd = pythonWeekday(today);

  if (op.freq == 'daily') {
    if (op.days == null || op.days!.isEmpty) return true;
    return op.days!.contains(todayWd);
  } else if (op.freq == 'period') {
    final limit = op.freqCount;
    final firstDay = DateTime(today.year, today.month, 1);
    final lastDay = DateTime(today.year, today.month + 1, 0);
    int count = 0;
    DateTime d = firstDay;
    while (!d.isAfter(lastDay)) {
      if (data.dailyLog[isoDate(d)]?[op.id] == true) count++;
      d = d.add(const Duration(days: 1));
    }
    return count < limit;
  } else if (op.freq == 'biweekly') {
    if (!op.biweeklyDays.contains(todayWd)) return false;
    if (op.biweeklyAnchor == null) return true;
    final anchor = parseIso(op.biweeklyAnchor!);
    final weeksSince = today.difference(anchor).inDays ~/ 7;
    return weeksSince % op.biweeklyWeeks == 0;
  }
  return true;
}

/// ─────────────────────────────────────────────────────────────
/// Apakah pos aktif hari ini — MODE BEKERJA
/// ─────────────────────────────────────────────────────────────
bool opActiveToday(AppData data, AllocItem op) {
  final today = DateTime.now();
  final todayWd = pythonWeekday(today);

  if (op.freq == 'daily') {
    if (op.days == null || op.days!.isEmpty) return true;
    return op.days!.contains(todayWd);
  } else if (op.freq == 'period') {
    final d = data.employed;
    final last = d.lastSalaryDate;
    if (last == null) return true;
    final start = parseIso(last);
    final since = today.difference(start).inDays;
    final scanDays = math.max(since + 1, d.salaryPeriodDays);
    int count = 0;
    for (int offset = 0; offset < scanDays; offset++) {
      final dt = start.add(Duration(days: offset));
      if (data.dailyLog[isoDate(dt)]?[op.id] == true) count++;
    }
    return count < op.freqCount;
  } else if (op.freq == 'biweekly') {
    if (!op.biweeklyDays.contains(todayWd)) return false;
    if (op.biweeklyAnchor == null) return true;
    final anchor = parseIso(op.biweeklyAnchor!);
    final weeksSince = today.difference(anchor).inDays ~/ 7;
    return weeksSince % op.biweeklyWeeks == 0;
  }
  return true;
}

/// (daysUntil, daysSince)
class SalaryDays {
  final int until;
  final int since;
  SalaryDays(this.until, this.since);
}

SalaryDays calcSalaryDays(EmployedData d) {
  final last = d.lastSalaryDate;
  if (last == null) return SalaryDays(d.salaryPeriodDays, 0);
  final since = DateTime.now().difference(parseIso(last)).inDays;
  return SalaryDays(
      math.max(0, d.salaryPeriodDays - since), math.min(since, d.salaryPeriodDays));
}

/// Estimasi total kebutuhan operasional per SATU PERIODE PENUH, dipakai untuk peringatan "operasional melebihi gaji".
double estimasiActiveOverPeriod(DateTime start, int period, List<AllocItem> ops) {
  double total = 0;
  final startWd = pythonWeekday(start);
  for (final op in ops) {
    int activeDays;
    if (op.freq == 'period') {
      activeDays = op.freqCount;
    } else if (op.freq == 'biweekly') {
      activeDays = 0;
      for (int offset = 0; offset < period; offset++) {
        if (op.biweeklyDays.contains((startWd + offset) % 7) &&
            (offset ~/ 7) % op.biweeklyWeeks == 0) {
          activeDays++;
        }
      }
    } else {
      final days = op.days;
      if (days == null || days.isEmpty) {
        activeDays = period;
      } else {
        activeDays = 0;
        for (int offset = 0; offset < period; offset++) {
          if (days.contains((startWd + offset) % 7)) activeDays++;
        }
      }
    }
    total += op.amount * activeDays;
  }
  return total;
}

/// Peringatan: total operasional per periode > gaji yang bisa dipakai.
/// Return null kalau aman, atau pesan kalau overlimit.
String? warnIfOperasionalOverlimit(AppData data) {
  final d = data.employed;
  if (d.salary <= 0 || d.salaryPeriodDays <= 0) return null;
  final spendable = d.salary * (1 - d.savingsPercent / 100);
  final start = d.lastSalaryDate != null ? parseIso(d.lastSalaryDate!) : DateTime.now();
  final totalOps = estimasiActiveOverPeriod(start, d.salaryPeriodDays, d.operationals);
  if (totalOps > spendable) {
    final selisih = totalOps - spendable;
    return 'Total operasional per periode:\n${fmt(totalOps)}\n\n'
        'Gaji yang bisa dipakai (setelah tabungan):\n${fmt(spendable)}\n\n'
        'Kelebihan: ${fmt(selisih)}\n\n'
        'Pertimbangkan kurangi jatah beberapa pos.';
  }
  return null;
}

/// Estimasi kebutuhan operasional SISA PERIODE (dari hari ini sampai akhir periode gaji), dipakai untuk cek saldo & sembunyikan pos non-prioritas.
double _estimasiSisaPeriode(
  AppData data,
  List<AllocItem> ops,
  DateTime start,
  DateTime todayD,
  int period,
  int daysLeft, {
  bool skipCheckedToday = false,
}) {
  double total = 0;
  final todayWd = pythonWeekday(todayD);
  final logToday = data.dailyLog[isoDate(todayD)] ?? const <String, bool>{};
  for (final op in ops) {
    final sudahHariIni = skipCheckedToday && logToday[op.id] == true;
    if (op.freq == 'period') {
      final since = todayD.difference(start).inDays;
      final scanDays = math.max(since + 1, period);
      int count = 0;
      for (int offset = 0; offset < scanDays; offset++) {
        final dt = start.add(Duration(days: offset));
        if (data.dailyLog[isoDate(dt)]?[op.id] == true) count++;
      }
      if (count < op.freqCount) total += op.amount;
    } else if (op.freq == 'biweekly') {
      final anchor = op.biweeklyAnchor != null ? parseIso(op.biweeklyAnchor!) : todayD;
      for (int offset = sudahHariIni ? 1 : 0; offset < daysLeft; offset++) {
        final dt = todayD.add(Duration(days: offset));
        final wd = pythonWeekday(dt);
        if (op.biweeklyDays.contains(wd) &&
            (dt.difference(anchor).inDays ~/ 7) % op.biweeklyWeeks == 0) {
          total += op.amount;
        }
      }
    } else {
      final days = op.days;
      final mulai = sudahHariIni ? 1 : 0;
      if (days == null || days.isEmpty) {
        total += op.amount * (daysLeft - mulai);
      } else {
        int cnt = 0;
        for (int offset = mulai; offset < daysLeft; offset++) {
          if (days.contains((todayWd + offset) % 7)) cnt++;
        }
        total += op.amount * cnt;
      }
    }
  }
  return total;
}

/// ─────────────────────────────────────────────────────────────
/// REKAP KEBUTUHAN SAMPAI GAJIAN BERIKUTNYA
/// ─────────────────────────────────────────────────────────────
class RekapKebutuhan {
  final double prioritas;
  final double nonPrioritas;
  final double saldo;
  final int daysLeft;

  const RekapKebutuhan({
    required this.prioritas,
    required this.nonPrioritas,
    required this.saldo,
    required this.daysLeft,
  });

  double get total => prioritas + nonPrioritas;

  /// Sisa saldo setelah semua kebutuhan sampai gajian ditutup.
  /// Negatif = memang kurang.
  double get sisaBebas => saldo - total;

  /// Sisa saldo kalau yang non-prioritas direm total.
  double get sisaKalauHematTotal => saldo - prioritas;

  /// Rata-rata uang bebas per hari sampai gajian.
  double get bebasPerHari => daysLeft > 0 ? sisaBebas / daysLeft : sisaBebas;

  bool get cukupSemua => sisaBebas >= 0;
  bool get cukupPrioritas => sisaKalauHematTotal >= 0;
}

RekapKebutuhan hitungRekapKebutuhan(AppData data) {
  final d = data.employed;
  final start =
      d.lastSalaryDate != null ? parseIso(d.lastSalaryDate!) : DateTime.now();
  final todayD = DateTime.now();
  final daysLeft = _daysLeftInPeriod(d, start, todayD);

  double est(List<AllocItem> ops) => _estimasiSisaPeriode(
        data,
        ops,
        start,
        todayD,
        d.salaryPeriodDays,
        daysLeft,
        skipCheckedToday: true,
      );

  return RekapKebutuhan(
    prioritas: est(d.operationals.where((o) => o.priority).toList()),
    nonPrioritas: est(d.operationals.where((o) => !o.priority).toList()),
    saldo: d.totalBalance,
    daysLeft: daysLeft,
  );
}

int _daysLeftInPeriod(EmployedData d, DateTime start, DateTime todayD) {
  final daysSinceStart = todayD.difference(start).inDays;
  return math.max(d.salaryPeriodDays - daysSinceStart, 1);
}

/// Daftar operasional yang tampil hari ini (menyembunyikan non-prioritas
List<AllocItem> visibleOperationalsToday(AppData data) {
  final d = data.employed;
  if (d.operationals.isEmpty) return [];
  if (d.totalBalance <= 0 || d.salary <= 0) return [];

  final activeOps = d.operationals.where((op) => opActiveToday(data, op)).toList();
  final start = d.lastSalaryDate != null ? parseIso(d.lastSalaryDate!) : DateTime.now();
  final todayD = DateTime.now();
  final daysLeft = _daysLeftInPeriod(d, start, todayD);

  final estAll = estimasiActiveOverPeriod(start, daysLeft, activeOps);
  if (d.totalBalance < estAll) {
    return activeOps.where((op) => op.priority).toList();
  }
  return activeOps;
}

/// Hasil cek saldo operasional (dipakai untuk munculkan dialog di UI)
class SaldoCheckResult {
  final String type; // 'none' | 'limited' | 'talangan' | 'critical'
  final String? message;
  SaldoCheckResult(this.type, this.message);
}

SaldoCheckResult checkSaldoOperasional(AppData data) {
  final d = data.employed;
  final today = todayStr();
  final log = data.dailyLog[today] ?? {};

  final start = d.lastSalaryDate != null ? parseIso(d.lastSalaryDate!) : DateTime.now();
  final todayD = DateTime.now();
  final daysLeft = _daysLeftInPeriod(d, start, todayD);

  final saldo = d.totalBalance;
  final savings = d.savingsBalance;

  final allOps = d.operationals
      .where((op) => opActiveToday(data, op) && log[op.id] != true)
      .toList();
  final nonPriorityOps = allOps.where((op) => !op.priority).toList();

  final estAll =
      _estimasiSisaPeriode(data, d.operationals, start, todayD, d.salaryPeriodDays, daysLeft);
  final estPriority = _estimasiSisaPeriode(
      data,
      d.operationals.where((o) => o.priority).toList(),
      start,
      todayD,
      d.salaryPeriodDays,
      daysLeft);

  if (saldo >= estAll) return SaldoCheckResult('none', null);

  if (saldo >= estPriority) {
    if (nonPriorityOps.isNotEmpty) {
      return SaldoCheckResult(
        'limited',
        'Saldo tidak cukup untuk semua operasional.\n\n'
        'Estimasi kebutuhan sampai akhir periode: ${fmt(estAll)}\n'
        'Saldo saat ini: ${fmt(saldo)}\n\n'
        'Pos non-prioritas disembunyikan otomatis.',
      );
    }
    return SaldoCheckResult('none', null);
  }

  if (saldo + savings >= estPriority) {
    final kekurangan = estPriority - saldo;
    withdrawFromSavings(data, amount: kekurangan, note: 'Talangan dari tabungan');
    return SaldoCheckResult(
      'talangan',
      'Saldo utama tidak cukup untuk operasional prioritas.\n\n'
      'Kekurangan: ${fmt(kekurangan)}\n'
      'Tabungan saat ini: ${fmt(savings)}\n\n'
      'Tabungan akan menutup kekurangan operasional prioritas.',
    );
  }

  return SaldoCheckResult(
    'critical',
    'Saldo dan tabungan tidak mencukupi operasional prioritas!\n\n'
    'Estimasi kebutuhan prioritas: ${fmt(estPriority)}\n'
    'Saldo: ${fmt(saldo)}\n'
    'Tabungan: ${fmt(savings)}\n\n'
    'Segera cari pemasukan tambahan.',
  );
}

/// Hasil toggleItem: gabungan cek saldo (mode employed) + reminder harga
class ToggleResult {
  final SaldoCheckResult? saldoCheck;
  final String? priceReminder;
  ToggleResult({this.saldoCheck, this.priceReminder});
}

/// Toggle checklist (centang / batal centang satu pos hari ini).
ToggleResult? toggleItem(AppData data, String itemId, bool checked, String mode,
    {double? actualAmount, String? accountId}) {
  final today = todayStr();
  data.dailyLog.putIfAbsent(today, () => {});

  final items = mode == 'unemployed' ? data.unemployed.dailyAllocations : data.employed.operationals;
  AllocItem? item;
  for (final i in items) {
    if (i.id == itemId) {
      item = i;
      break;
    }
  }
  if (item == null) return null;
  final it = item; // non-null lokal, supaya aman dipakai di closure/where()

  final was = data.dailyLog[today]![itemId] ?? false;
  data.dailyLog[today]![itemId] = checked;

  final hist = mode == 'unemployed' ? data.unemployed.history : data.employed.history;

  if (checked && !was) {
    final amt = it.variableAmount ? (actualAmount ?? it.amount) : it.amount;

    addExpense(data,
        amount: amt, note: it.label, itemId: it.id, date: today, mode: mode, accountId: accountId);
    if (it.freq == 'biweekly' && it.biweeklyAnchor == null) {
      it.biweeklyAnchor = today;
    }

    String? reminder;
    if (it.variableAmount) {
      it.recentAmounts.add(amt);
      if (it.recentAmounts.length > 3) it.recentAmounts.removeAt(0);
      if (it.recentAmounts.length == 3) {
        final aboveCount = it.recentAmounts.where((a) => a > it.amount).length;
        if (aboveCount >= 2) {
          final avg = it.recentAmounts.reduce((a, b) => a + b) / it.recentAmounts.length;
          reminder = 'Pos "${it.label}" 3 kali terakhir sering di atas jatah (${fmt(it.amount)}).\n'
              'Rata-rata real terakhir: ${fmt(avg)}.\n\n'
              'Pertimbangkan update jatah default-nya di tab Alokasi.';
        }
      }
    }

    final saldoResult = mode == 'employed' ? checkSaldoOperasional(data) : null;
    return ToggleResult(saldoCheck: saldoResult, priceReminder: reminder);
  } else if (!checked && was) {
    final entry = _findEntryForItem(hist, it, today);
    if (entry != null) {
      // deleteEntry sudah sekalian mengembalikan saldo, melepas centang,
      // dan membatalkan catatan tren harga.
      deleteEntry(data, entry.id, mode);
    } else {
      // Tidak ada entri pasangannya (mis. sudah dihapus manual dari Riwayat).
      // Cukup lepas centangnya, saldo tidak perlu disentuh.
      data.dailyLog[today]![itemId] = false;
    }
  }
  return null;
}

/// Cari baris riwayat milik satu pos pada tanggal tertentu.
HistoryEntry? _findEntryForItem(
    List<HistoryEntry> hist, AllocItem it, String date) {
  for (int i = hist.length - 1; i >= 0; i--) {
    final h = hist[i];
    if (h.itemId == it.id && h.date == date && h.type == 'expense') return h;
  }
  for (int i = hist.length - 1; i >= 0; i--) {
    final h = hist[i];
    if (h.itemId == null &&
        h.kind == 'normal' &&
        h.note == it.label &&
        h.date == date &&
        h.type == 'expense') {
      return h;
    }
  }
  return null;
}

/// ─────────────────────────────────────────────────────────────
/// RESET
/// ─────────────────────────────────────────────────────────────
void resetToday(AppData data) {
  final mode = data.mode;
  final items = mode == 'unemployed' ? data.unemployed.dailyAllocations : data.employed.operationals;
  final today = todayStr();
  final log = data.dailyLog[today] ?? {};
  final hist = mode == 'unemployed' ? data.unemployed.history : data.employed.history;

  for (final item in items) {
    if (log[item.id] == true) {
      final entry = _findEntryForItem(hist, item, today);
      if (entry != null) deleteEntry(data, entry.id, mode);
    }
  }
  data.dailyLog[today] = {};
}

void resetSaldoEmployed(AppData data) {
  final d = data.employed;
  for (final a in d.accounts.where((a) => !a.isSavings)) {
    if (a.balance != 0) setBalanceManual(data, 0, accountId: a.id);
  }
}

void resetHistoryEmployed(AppData data) {
  data.employed.history = [];
}

void resetAllUnemployed(AppData data) {
  final d = data.unemployed;
  final today = DateTime.now();
  d.totalBalance = 0;
  d.history = [];
  final firstDay = DateTime(today.year, today.month, 1);
  final lastDay = DateTime(today.year, today.month + 1, 0);
  final allocIds = d.dailyAllocations.map((a) => a.id).toSet();
  DateTime day = firstDay;
  while (!day.isAfter(lastDay)) {
    final ds = isoDate(day);
    final log = data.dailyLog[ds];
    if (log != null) {
      for (final id in allocIds) {
        log.remove(id);
      }
    }
    day = day.add(const Duration(days: 1));
  }
}

void resetAllEmployed(AppData data) {
  final d = data.employed;
  for (final a in d.accounts) {
    a.balance = 0;
  }
  d.history = [];
  d.lastSalaryDate = null;
  data.dailyLog[todayStr()] = {};
}

/// ─────────────────────────────────────────────────────────────
/// RIWAYAT: rekap harian & per periode gaji
/// ─────────────────────────────────────────────────────────────

bool entryCountsInSummary(HistoryEntry e) => e.kind != 'transfer' && e.kind != 'adjust';

class DayGroup {
  final String date;
  final List<HistoryEntry> entries;
  final double income;
  final double expense;
  const DayGroup({
    required this.date,
    required this.entries,
    required this.income,
    required this.expense,
  });
  double get net => income - expense;
}

/// Kelompokkan riwayat per tanggal, urut TERLAMA -> TERBARU.
List<DayGroup> groupByDay(List<HistoryEntry> entries) {
  final byDate = <String, List<HistoryEntry>>{};
  for (final e in entries) {
    byDate.putIfAbsent(e.date, () => []).add(e);
  }
  final dates = byDate.keys.toList()..sort();
  return dates.map((date) {
    final list = byDate[date]!;
    double inc = 0, exp = 0;
    for (final e in list) {
      if (!entryCountsInSummary(e)) continue;
      if (e.type == 'income') {
        inc += e.amount;
      } else {
        exp += e.amount;
      }
    }
    return DayGroup(date: date, entries: list, income: inc, expense: exp);
  }).toList();
}

const _bulanPendek = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

String fmtTanggalPendek(String iso) {
  final d = parseIso(iso);
  return '${d.day} ${_bulanPendek[d.month - 1]}';
}

class SalaryPeriod {
  final String label;
  final String startDate; // inklusif
  final String? endDate; // inklusif, null = masih berjalan (sampai hari ini)
  const SalaryPeriod({required this.label, required this.startDate, this.endDate});
}

/// Daftar periode gaji, 
List<SalaryPeriod> salaryPeriods(EmployedData d) {
  final salaryDates = d.history
      .where((e) => e.kind == 'salary')
      .map((e) => e.date)
      .toSet()
      .toList()
    ..sort();
  if (salaryDates.isEmpty) return [];

  final periods = <SalaryPeriod>[];
  for (int i = 0; i < salaryDates.length; i++) {
    final start = salaryDates[i];
    final end = i + 1 < salaryDates.length
        ? isoDate(parseIso(salaryDates[i + 1]).subtract(const Duration(days: 1)))
        : null;
    final label = end == null
        ? '${fmtTanggalPendek(start)} — sekarang'
        : '${fmtTanggalPendek(start)} – ${fmtTanggalPendek(end)}';
    periods.add(SalaryPeriod(label: label, startDate: start, endDate: end));
  }
  return periods.reversed.toList();
}

List<HistoryEntry> entriesInPeriod(List<HistoryEntry> all, SalaryPeriod p) {
  return all.where((e) {
    if (e.date.compareTo(p.startDate) < 0) return false;
    if (p.endDate != null && e.date.compareTo(p.endDate!) > 0) return false;
    return true;
  }).toList();
}
