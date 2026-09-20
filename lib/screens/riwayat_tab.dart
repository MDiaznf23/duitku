import 'package:flutter/material.dart';
import '../models.dart';
import '../logic.dart';
import '../theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';

class RiwayatTab extends StatefulWidget {
  final AppData data;
  final Future<void> Function() onChanged;
  const RiwayatTab({super.key, required this.data, required this.onChanged});

  @override
  State<RiwayatTab> createState() => _RiwayatTabState();
}

class _RiwayatTabState extends State<RiwayatTab> {
  // 0 = "Semua Waktu"; 1..n = index ke periods[i-1]
  int _periodIndex = 0;

  Future<void> _delete(BuildContext context, HistoryEntry e) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus Transaksi',
      message: '${e.note}\n${e.type == "income" ? "+" : "-"}${fmt(e.amount)} '
          '• ${e.date}\n\nSaldo akan dikembalikan seperti sebelum transaksi ini.',
    );
    if (!ok) return;

    final res = deleteEntry(widget.data, e.id);
    if (!res.ok) {
      if (context.mounted) {
        await showInfoDialog(context,
            title: 'Tidak Bisa Dihapus',
            message: res.reason ?? '',
            color: context.colors.yellow);
      }
      return;
    }
    await widget.onChanged();
  }

  String _accountLabel(String? id) {
    if (id == null) return '-';
    for (final a in widget.data.employed.accounts) {
      if (a.id == id) return a.label;
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isEmployed = data.mode == 'employed';
    final allHistory = isEmployed ? data.employed.history : data.unemployed.history;
    final periods = isEmployed ? salaryPeriods(data.employed) : const <SalaryPeriod>[];
    final showAccounts = isEmployed && data.employed.accounts.length > 1;

    // Kalau riwayat berubah (mis. entri gaji dihapus) dan index periode yang
    // sedang dipilih sudah tidak ada lagi, balik ke "Semua Waktu" saja.
    if (_periodIndex > periods.length) _periodIndex = 0;

    List<HistoryEntry> visible;
    String periodTitle;
    if (isEmployed && _periodIndex > 0) {
      final p = periods[_periodIndex - 1];
      visible = entriesInPeriod(allHistory, p);
      periodTitle = 'Periode ${p.label}';
    } else {
      visible = allHistory;
      periodTitle = 'Semua Waktu';
    }

    final daysAsc = groupByDay(visible); // terlama -> terbaru, untuk chart
    final daysDesc = daysAsc.reversed.toList(); // terbaru -> terlama, untuk list
    final totalIncome = daysAsc.fold(0.0, (s, d) => s + d.income);
    final totalExpense = daysAsc.fold(0.0, (s, d) => s + d.expense);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Riwayat Transaksi'),
          if (isEmployed && periods.isNotEmpty) ...[
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _periodChip(context, 'Semua Waktu', _periodIndex == 0, () {
                    setState(() => _periodIndex = 0);
                  }),
                  for (int i = 0; i < periods.length; i++)
                    _periodChip(context, periods[i].label, _periodIndex == i + 1, () {
                      setState(() => _periodIndex = i + 1);
                    }),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Belum ada riwayat pada rentang ini',
                  style: TextStyle(color: context.colors.textMuted)),
            )
          else ...[
            HistorySummaryCard(title: periodTitle, income: totalIncome, expense: totalExpense),
            DailyBarChart(days: daysAsc),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Geser baris ke kiri untuk menghapus satu transaksi.',
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
            ),
            ...daysDesc.map((day) => _dayBlock(context, day, showAccounts)),
          ],
        ],
      ),
    );
  }

  Widget _periodChip(BuildContext context, String label, bool selected, VoidCallback onTap) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: c.accent,
        labelStyle: TextStyle(color: selected ? c.onAccent : c.textMain),
        backgroundColor: c.card,
        side: BorderSide(color: c.border),
      ),
    );
  }

  Widget _dayBlock(BuildContext context, DayGroup day, bool showAccounts) {
    final c = context.colors;
    final entries = day.entries.reversed.toList(); // terbaru dulu dalam sehari
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(day.date,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: c.textMain)),
              ),
              if (day.income > 0)
                Text('+${fmt(day.income)}  ',
                    style: TextStyle(fontSize: 10, color: c.green, fontWeight: FontWeight.w600)),
              if (day.expense > 0)
                Text('-${fmt(day.expense)}',
                    style: TextStyle(fontSize: 10, color: c.red, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          ...entries.map((h) => Dismissible(
                key: ValueKey(h.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await _delete(context, h);
                  return false;
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: c.redDark,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.delete_outline, color: c.onRedDark, size: 20),
                ),
                child: HistoryRowTile(
                  entry: h,
                  accountLabel: showAccounts ? _accountLabel : null,
                ),
              )),
        ],
      ),
    );
  }
}
