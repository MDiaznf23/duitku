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
  int daysLeft,
) {
  double total = 0;
  final todayWd = pythonWeekday(todayD);
  for (final op in ops) {
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
      for (int offset = 0; offset < daysLeft; offset++) {
        final dt = todayD.add(Duration(days: offset));
        final wd = pythonWeekday(dt);
        if (op.biweeklyDays.contains(wd) &&
            (dt.difference(anchor).inDays ~/ 7) % op.biweeklyWeeks == 0) {
          total += op.amount;
        }
      }
    } else {
      final days = op.days;
      if (days == null || days.isEmpty) {
        total += op.amount * daysLeft;
      } else {
        int cnt = 0;
        for (int offset = 0; offset < daysLeft; offset++) {
          if (days.contains((todayWd + offset) % 7)) cnt++;
        }
        total += op.amount * cnt;
      }
    }
  }
  return total;
}

int _daysLeftInPeriod(EmployedData d, DateTime start, DateTime todayD) {
  final daysSinceStart = todayD.difference(start).inDays;
  return math.max(d.salaryPeriodDays - daysSinceStart, 1);
}

/// Daftar operasional yang tampil hari ini (menyembunyikan non-prioritas
/// otomatis kalau saldo diperkirakan tidak cukup sampai akhir periode).
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

/// Port dari _check_saldo_operasional — bisa MEMUTASI data.employed (memakai tabungan sebagai talangan) sehingga caller wajib Store.save setelah memanggil ini kalau type == 'talangan'.
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
    d.savingsBalance -= kekurangan;
    d.totalBalance += kekurangan;
    d.history.add(HistoryEntry(
        date: today, type: 'income', note: 'Talangan dari tabungan', amount: kekurangan));
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
ToggleResult? toggleItem(AppData data, String itemId, bool checked, String mode, {double? actualAmount}) {
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

    if (mode == 'unemployed') {
      data.unemployed.totalBalance -= amt;
    } else {
      data.employed.totalBalance -= amt;
    }
    hist.add(HistoryEntry(date: today, type: 'expense', note: it.label, amount: amt));
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
    // Cari entri histori aslinya supaya jumlah yang dikembalikan SESUAI
    double refunded = it.amount;
    for (int i = hist.length - 1; i >= 0; i--) {
      if (hist[i].note == it.label && hist[i].date == today && hist[i].type == 'expense') {
        refunded = hist[i].amount;
        hist.removeAt(i);
        break;
      }
    }

    if (mode == 'unemployed') {
      data.unemployed.totalBalance += refunded;
    } else {
      data.employed.totalBalance += refunded;
    }

    // Batalkan pencatatan tren harga untuk nilai yang baru saja di-undo.
    if (it.variableAmount && it.recentAmounts.isNotEmpty && it.recentAmounts.last == refunded) {
      it.recentAmounts.removeLast();
    }
  }
  return null;
}

/// ─────────────────────────────────────────────────────────────
/// RESET
/// ─────────────────────────────────────────────────────────────
void resetToday(AppData data) {
  final mode = data.mode;
  final kd = mode == 'unemployed' ? data.unemployed : data.employed;
  final items = mode == 'unemployed' ? data.unemployed.dailyAllocations : data.employed.operationals;
  final today = todayStr();
  final log = data.dailyLog[today] ?? {};
  final hist = mode == 'unemployed' ? data.unemployed.history : data.employed.history;

  for (final item in items) {
    if (log[item.id] == true) {
      double refunded = item.amount;
      for (int i = hist.length - 1; i >= 0; i--) {
        if (hist[i].note == item.label && hist[i].date == today && hist[i].type == 'expense') {
          refunded = hist[i].amount;
          hist.removeAt(i);
          break;
        }
      }
      if (mode == 'unemployed') {
        data.unemployed.totalBalance += refunded;
      } else {
        data.employed.totalBalance += refunded;
      }
      // Batalkan pencatatan tren harga untuk nilai yang baru saja di-reset.
      if (item.variableAmount && item.recentAmounts.isNotEmpty && item.recentAmounts.last == refunded) {
        item.recentAmounts.removeLast();
      }
    }
  }
  data.dailyLog[today] = {};
}

void resetSaldoEmployed(AppData data) {
  final d = data.employed;
  d.totalBalance = 0;
  d.history = d.history.where((h) => h.type != 'income').toList();
  d.history.add(HistoryEntry(date: todayStr(), type: 'expense', note: 'Reset saldo manual', amount: 0));
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
  d.totalBalance = 0;
  d.savingsBalance = 0;
  d.history = [];
  d.lastSalaryDate = null;
  data.dailyLog[todayStr()] = {};
}
