import 'package:flutter/material.dart';
import '../models.dart';
import '../logic.dart';
import '../theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';

class BerandaTab extends StatelessWidget {
  final AppData data;
  final Future<void> Function() onChanged;
  const BerandaTab({super.key, required this.data, required this.onChanged});

  Future<void> _handleToggle(BuildContext context, AllocItem item, bool checked, String mode) async {
    double? actualAmount;
    String? accountId;
    if (checked && item.variableAmount) {
      final isEmployed = mode == 'employed';
      final res = await showAmountDialog(
        context,
        title: 'Jumlah Real: ${item.label}',
        initialAmount: item.amount.toStringAsFixed(0),
        withNote: false,
        accounts: isEmployed ? data.employed.accounts.where((a) => !a.isSavings).toList() : null,
      );
      if (res == null) return; // user batal
      actualAmount = res['amount'] as double;
      accountId = res['accountId'] as String?;
    }

    final result = toggleItem(data, item.id, checked, mode, actualAmount: actualAmount, accountId: accountId);
    await onChanged();
    if (result == null || !context.mounted) return;

    if (result.priceReminder != null) {
      await showInfoDialog(context, title: 'Cek Jatah Pos', message: result.priceReminder!, color: context.colors.tertiary);
    }

    final sc = result.saldoCheck;
    if (sc != null && sc.type != 'none' && context.mounted) {
      final color = sc.type == 'critical'
          ? context.colors.red
          : sc.type == 'talangan'
              ? context.colors.tertiary
              : context.colors.textMain;
      final titleMap = {
        'limited': 'Saldo Terbatas',
        'talangan': 'Tabungan Digunakan',
        'critical': 'Saldo Kritis',
      };
      await showInfoDialog(context, title: titleMap[sc.type] ?? 'Info', message: sc.message ?? '', color: color);
      if (sc.type == 'talangan') await onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = todayStr();
    final log = data.dailyLog[today] ?? {};
    final mode = data.mode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == 'unemployed') ..._buildUnemployed(context, log) else ..._buildEmployed(context, log, today),
        ],
      ),
    );
  }

  List<Widget> _buildUnemployed(BuildContext context, Map<String, bool> log) {
    final d = data.unemployed;
    double totalAlloc = 0;
    double sisaJatah = 0;
    if (d.totalBalance > 0) {
      totalAlloc = d.dailyAllocations
          .where((a) => opActiveTodayUnemployed(data, a))
          .fold(0, (s, a) => s + a.amount);
      sisaJatah = d.dailyAllocations
          .where((a) => opActiveTodayUnemployed(data, a) && log[a.id] != true)
          .fold(0, (s, a) => s + a.amount);
    }
    final cards = [
      StatCard(label: 'Saldo', value: fmt(d.totalBalance), color: context.colors.accent),
      StatCard(label: 'Jatah/Hari', value: fmt(totalAlloc), color: context.colors.secondary),
      StatCard(label: 'Sisa Hari Ini', value: fmt(sisaJatah), color: sisaJatah >= 0 ? context.colors.secondary : context.colors.red),
      if (totalAlloc > 0)
        StatCard(label: 'Tahan ~', value: '${(d.totalBalance / totalAlloc).floor()} hari', color: context.colors.tertiary),
    ];

    final activeAllocs = d.dailyAllocations.where((a) => opActiveTodayUnemployed(data, a)).toList();

    return [
      StatGrid(cards),
      const SectionTitle('Checklist Hari Ini'),
      if (d.dailyAllocations.isEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Belum ada alokasi. Tambah di tab Alokasi.', style: TextStyle(color: context.colors.textMuted)),
        )
      else if (activeAllocs.isEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Tidak ada alokasi untuk hari ini.', style: TextStyle(color: context.colors.textMuted)),
        )
      else
        ...activeAllocs.map((a) => TaskRowTile(
              item: a,
              checked: log[a.id] == true,
              onToggle: (v) => _handleToggle(context, a, v, 'unemployed'),
            )),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionButton(
              label: '+ Uang Masuk',
              color: context.colors.secondaryDark,
              foreground: context.colors.onSecondaryDark,
              onPressed: () async {
                final res = await showAmountDialog(context, title: '+ Uang Masuk', noteHint: 'Uang masuk');
                if (res != null) {
                  addIncome(data,
                      amount: res['amount'] as double,
                      note: (res['note'] as String).isEmpty
                          ? 'Uang masuk'
                          : res['note'] as String);
                  await onChanged();
                }
              }),
          ActionButton(
              label: '- Pengeluaran',
              color: context.colors.tertiaryDark,
              foreground: context.colors.onTertiaryDark,
              onPressed: () async {
                final res = await showAmountDialog(context, title: '- Pengeluaran', noteHint: 'Pengeluaran');
                if (res != null) {
                  addExpense(data,
                      amount: res['amount'] as double,
                      note: (res['note'] as String).isEmpty
                          ? 'Pengeluaran'
                          : res['note'] as String);
                  await onChanged();
                }
              }),
          ActionButton(
              label: '✎ Set Saldo',
              color: context.colors.accentDark,
              foreground: context.colors.onAccentDark,
              onPressed: () async {
                final res = await showAmountDialog(context,
                    title: 'Set Saldo Manual', initialAmount: d.totalBalance.toStringAsFixed(0), withNote: false);
                if (res != null) {
                  setBalanceManual(data, res['amount'] as double);
                  await onChanged();
                }
              }),
        ],
      ),
    ];
  }

  List<Widget> _buildEmployed(BuildContext context, Map<String, bool> log, String today) {
    final d = data.employed;
    final salary = d.salary;
    double sisaJatah = 0;
    if (d.totalBalance > 0) {
      sisaJatah = d.operationals
          .where((o) => opActiveToday(data, o) && log[o.id] != true)
          .fold(0, (s, o) => s + o.amount);
    }
    final sd = calcSalaryDays(d);

    final cards = [
      StatCard(label: 'Saldo', value: fmt(d.totalBalance), color: context.colors.accent),
      StatCard(label: 'Tabungan', value: fmt(d.savingsBalance), color: context.colors.tertiary),
      StatCard(label: 'Sisa Hari Ini', value: fmt(sisaJatah), color: sisaJatah >= 0 ? context.colors.secondary : context.colors.red),
      StatCard(label: 'Gajian lagi', value: '${sd.until} hari', color: context.colors.secondary),
    ];

    final pct = d.salaryPeriodDays > 0 ? (sd.since / d.salaryPeriodDays * 100).clamp(0, 100) : 0.0;
    final progColor = pct < 70 ? context.colors.accent : (pct < 90 ? context.colors.tertiary : context.colors.red);

    final activeOps = visibleOperationalsToday(data);

    return [
      StatGrid(cards),
      AccountBreakdown(accounts: d.accounts.where((a) => !a.isSavings).toList()),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: context.colors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.colors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Periode Gaji (hari ke-${sd.since}/${d.salaryPeriodDays})',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 8,
                backgroundColor: context.colors.muted,
                valueColor: AlwaysStoppedAnimation(progColor),
              ),
            ),
          ],
        ),
      ),
      if (d.salary > 0 && d.operationals.isNotEmpty)
        RekapKebutuhanCard(rekap: hitungRekapKebutuhan(data)),
      const SectionTitle('Operasional Hari Ini'),
      if (d.operationals.isEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Belum ada operasional. Tambah di tab Alokasi.', style: TextStyle(color: context.colors.textMuted)),
        )
      else if (d.totalBalance <= 0 || salary <= 0)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text('Input Gaji Dulu!', style: TextStyle(color: context.colors.tertiary, fontWeight: FontWeight.bold)),
          ),
        )
      else if (activeOps.isEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Tidak ada operasional untuk hari ini.', style: TextStyle(color: context.colors.textMuted)),
        )
      else
        ...activeOps.map((o) => TaskRowTile(
              item: o,
              checked: log[o.id] == true,
              onToggle: (v) => _handleToggle(context, o, v, 'employed'),
            )),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.6,
        children: [
          ActionButton(
              label: '+ Input Gaji',
              color: context.colors.secondaryDark,
              foreground: context.colors.onSecondaryDark,
              onPressed: () async {
                final res = await showSalaryDialog(context, d);
                if (res != null) {
                  addSalary(data, res['amount'] as double, accountId: res['accountId'] as String?);
                  await onChanged();
                  final result = checkSaldoOperasional(data);
                  if (result.type != 'none' && context.mounted) {
                    await showInfoDialog(context, title: 'Info Saldo', message: result.message ?? '');
                    await onChanged();
                  }
                }
              }),
          ActionButton(
              label: '+ Pemasukan',
              color: context.colors.secondaryDark,
              foreground: context.colors.onSecondaryDark,
              onPressed: () async {
                final res = await showAmountDialog(context,
                    title: '+ Pemasukan Tambahan',
                    noteHint: 'Pemasukan tambahan',
                    accounts: d.accounts.where((a) => !a.isSavings).toList());
                if (res != null) {
                  addIncome(data,
                      amount: res['amount'] as double,
                      note: (res['note'] as String).isEmpty
                          ? 'Pemasukan tambahan'
                          : res['note'] as String,
                      accountId: res['accountId'] as String?);
                  await onChanged();
                  final result = checkSaldoOperasional(data);
                  if (result.type != 'none' && context.mounted) {
                    await showInfoDialog(context, title: 'Info Saldo', message: result.message ?? '');
                    await onChanged();
                  }
                }
              }),
          ActionButton(
              label: '- Pengeluaran',
              color: context.colors.tertiaryDark,
              foreground: context.colors.onTertiaryDark,
              onPressed: () async {
                final res = await showAmountDialog(context,
                    title: '- Pengeluaran',
                    noteHint: 'Pengeluaran',
                    accounts: d.accounts.where((a) => !a.isSavings).toList());
                if (res != null) {
                  addExpense(data,
                      amount: res['amount'] as double,
                      note: (res['note'] as String).isEmpty
                          ? 'Pengeluaran'
                          : res['note'] as String,
                      accountId: res['accountId'] as String?);
                  await onChanged();
                  final result = checkSaldoOperasional(data);
                  if (result.type != 'none' && context.mounted) {
                    await showInfoDialog(context, title: 'Info Saldo', message: result.message ?? '');
                    await onChanged();
                  }
                }
              }),
          if (d.accounts.length > 1)
            ActionButton(
                label: '\u21c4 Pindah Kantong',
                color: context.colors.muted,
                foreground: context.colors.onMuted,
                onPressed: () async {
                  final res = await showTransferDialog(context, accounts: d.accounts);
                  if (res == null) return;
                  final amt = res['amount'] as double;
                  final from = d.accountById(res['from'] as String);
                  if (amt > from.balance) {
                    if (context.mounted) {
                      await showInfoDialog(context,
                          title: 'Saldo Kurang',
                          message: '${from.label} cuma ${fmt(from.balance)}.',
                          color: context.colors.red);
                    }
                    return;
                  }
                  transferBetweenAccounts(data,
                      fromAccountId: res['from'] as String,
                      toAccountId: res['to'] as String,
                      amount: amt,
                      note: (res['note'] as String).isEmpty ? 'Pindah kantong' : res['note'] as String);
                  await onChanged();
                }),
          ActionButton(
              label: '\u2197 Ke Tabungan',
              color: context.colors.accentDark,
              foreground: context.colors.onAccentDark,
              onPressed: () async {
                final nonSavings = d.accounts.where((a) => !a.isSavings).toList();
                final res = await showAmountDialog(context,
                    title: 'Pindah ke Tabungan',
                    withNote: false,
                    accounts: nonSavings);
                if (res == null) return;
                final amt = res['amount'] as double;
                if (amt <= 0) return;
                final fromId = res['accountId'] as String? ?? d.defaultAccount.id;
                final from = d.accountById(fromId);
                if (amt > from.balance) {
                  if (context.mounted) {
                    await showInfoDialog(context,
                        title: 'Saldo Kurang',
                        message: '${from.label} cuma ${fmt(from.balance)}.',
                        color: context.colors.red);
                  }
                  return;
                }
                transferToSavings(data, amount: amt, fromAccountId: fromId);
                await onChanged();
                final result = checkSaldoOperasional(data);
                if (result.type != 'none' && context.mounted) {
                  await showInfoDialog(context,
                      title: 'Info Saldo', message: result.message ?? '');
                  await onChanged();
                }
              }),
          ActionButton(
              label: '\u2199 Ambil Tabungan',
              color: context.colors.muted,
              foreground: context.colors.onMuted,
              onPressed: () async {
                final nonSavings = d.accounts.where((a) => !a.isSavings).toList();
                final res = await showAmountDialog(context,
                    title: 'Ambil dari Tabungan',
                    withNote: false,
                    accounts: nonSavings);
                if (res == null) return;
                final amt = res['amount'] as double;
                if (amt <= 0) return;
                if (amt > d.savingsBalance) {
                  if (context.mounted) {
                    await showInfoDialog(context,
                        title: 'Tabungan Kurang',
                        message: 'Tabungan kamu cuma ${fmt(d.savingsBalance)}.',
                        color: context.colors.red);
                  }
                  return;
                }
                withdrawFromSavings(data,
                    amount: amt, toAccountId: res['accountId'] as String?);
                await onChanged();
              }),
        ],
      ),
    ];
  }
}
