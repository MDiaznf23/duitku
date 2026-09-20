import 'package:flutter/material.dart';
import '../models.dart';
import '../logic.dart';
import '../theme.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: context.colors.textMain)),
      );
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const StatCard({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final valueColor = color ?? context.colors.textMain;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.statCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class StatGrid extends StatelessWidget {
  final List<StatCard> cards;
  const StatGrid(this.cards, {super.key});
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: cards,
    );
  }
}

class TaskRowTile extends StatelessWidget {
  final AllocItem item;
  final bool checked;
  final ValueChanged<bool> onToggle;
  const TaskRowTile({super.key, required this.item, required this.checked, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final color = checked ? context.colors.textMuted : context.colors.textMain;
    final amtColor = checked ? context.colors.textMuted : context.colors.accent;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            activeColor: context.colors.accent,
            onChanged: (v) => onToggle(v ?? false),
          ),
          Expanded(
            child: Text('${checked ? "✓" : "○"} ${item.label}',
                style: TextStyle(fontSize: 13, color: color)),
          ),
          Text(fmt(item.amount),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: amtColor)),
        ],
      ),
    );
  }
}

class AllocRowTile extends StatelessWidget {
  final AllocItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const AllocRowTile({super.key, required this.item, required this.onEdit, required this.onDelete});

  String get _freqLabel {
    switch (item.freq) {
      case 'period':
        return '${item.freqCount}x / periode';
      case 'biweekly':
        return 'tiap ${item.biweeklyWeeks} minggu';
      default:
        return (item.days == null || item.days!.isEmpty) ? 'tiap hari' : 'hari tertentu';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.statCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.label, style: TextStyle(fontSize: 13, color: context.colors.textMain)),
                const SizedBox(height: 2),
                Text('${fmt(item.amount)} • $_freqLabel${item.priority ? " • prioritas" : ""}',
                    style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, size: 18, color: context.colors.textMain),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: context.colors.red),
            onPressed: onDelete,
            tooltip: 'Hapus',
          ),
        ],
      ),
    );
  }
}

class HistoryRowTile extends StatelessWidget {
  final HistoryEntry entry;
  final String Function(String? id)? accountLabel;
  const HistoryRowTile({super.key, required this.entry, this.accountLabel});

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type == 'income';
    final isTransfer = entry.kind == 'transfer';
    final color = isTransfer
        ? context.colors.tertiary
        : (isIncome ? context.colors.green : context.colors.red);
    final sign = isTransfer ? (isIncome ? '↙' : '↗') : (isIncome ? '+' : '-');

    String? kantongLabel;
    if (accountLabel != null && entry.accountId != null) {
      kantongLabel = isTransfer
          ? (isIncome
              ? '${accountLabel!(entry.toAccountId)} → ${accountLabel!(entry.accountId)}'
              : '${accountLabel!(entry.accountId)} → ${accountLabel!(entry.toAccountId)}')
          : accountLabel!(entry.accountId);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.statCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Text(entry.date, style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(entry.note,
                          style: TextStyle(fontSize: 12, color: context.colors.textMain),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (entry.locked) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_outline, size: 11, color: context.colors.textMuted),
                    ],
                  ],
                ),
                if (kantongLabel != null)
                  Text(kantongLabel,
                      style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
              ],
            ),
          ),
          Text('$sign${fmt(entry.amount)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color foreground;
  final bool outlined;
  final VoidCallback onPressed;
  const ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.foreground,
    this.outlined = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Kartu rekap kebutuhan sampai gajian berikutnya.
/// ─────────────────────────────────────────────────────────────
class RekapKebutuhanCard extends StatelessWidget {
  final RekapKebutuhan rekap;
  const RekapKebutuhanCard({super.key, required this.rekap});

  Widget _baris(BuildContext context, String label, String value, Color dot,
      {bool tebal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: tebal
                        ? context.colors.textMain
                        : context.colors.textMuted)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: tebal ? FontWeight.bold : FontWeight.w600,
                  color: context.colors.textMain)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final saldo = rekap.saldo;
    final bebas = rekap.sisaBebas;

    final skala = saldo > rekap.total ? saldo : rekap.total;
    double frac(double v) => skala > 0 ? (v / skala).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kebutuhan sampai gajian (${rekap.daysLeft} hari lagi)',
              style: TextStyle(fontSize: 11, color: c.textMuted)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                      flex: (frac(rekap.prioritas) * 1000).round(),
                      child: Container(color: c.red)),
                  Expanded(
                      flex: (frac(rekap.nonPrioritas) * 1000).round(),
                      child: Container(color: c.yellow)),
                  Expanded(
                      flex: (frac(bebas > 0 ? bebas : 0) * 1000).round(),
                      child: Container(color: c.green)),
                  // penjaga supaya Row tidak kosong kalau semua nol
                  if (skala <= 0)
                    Expanded(flex: 1000, child: Container(color: c.muted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _baris(context, 'Wajib (prioritas)', fmt(rekap.prioritas), c.red),
          _baris(context, 'Bisa direm (non-prioritas)', fmt(rekap.nonPrioritas),
              c.yellow),
          Divider(height: 14, color: c.border),
          _baris(
              context,
              bebas >= 0 ? 'Bebas dipakai' : 'Kurang',
              fmt(bebas),
              bebas >= 0 ? c.green : c.red,
              tebal: true),
          const SizedBox(height: 4),
          Text(
            bebas >= 0
                ? 'Sekitar ${fmt(rekap.bebasPerHari)}/hari di luar pos yang sudah diatur.'
                : rekap.cukupPrioritas
                    ? 'Kalau pos non-prioritas direm total, masih sisa ${fmt(rekap.sisaKalauHematTotal)}.'
                    : 'Kebutuhan prioritas saja sudah kurang ${fmt(-rekap.sisaKalauHematTotal)}.',
            style: TextStyle(fontSize: 10, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Rincian saldo per kantong (Tunai, BCA, GoPay, dst). Muncul di Beranda
/// ─────────────────────────────────────────────────────────────
class AccountBreakdown extends StatelessWidget {
  final List<Account> accounts; // non-tabungan saja
  const AccountBreakdown({super.key, required this.accounts});

  @override
  Widget build(BuildContext context) {
    if (accounts.length <= 1) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: accounts
            .map((a) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${a.label}: ',
                        style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                    Text(fmt(a.balance),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textMain)),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

/// Satu baris kantong di layar "Kelola Kantong" (Pengaturan).
class AccountRowTile extends StatelessWidget {
  final Account account;
  final VoidCallback onSetBalance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const AccountRowTile({
    super.key,
    required this.account,
    required this.onSetBalance,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.statCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(account.label, style: TextStyle(fontSize: 13, color: c.textMain)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: account.isSavings ? c.tertiary : c.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        account.isSavings ? 'Tabungan' : (accountTypeLabels[account.type] ?? account.type),
                        style: TextStyle(
                            fontSize: 9,
                            color: account.isSavings ? c.tertiary : c.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(fmt(account.balance),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.accent)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: c.textMain),
            tooltip: 'Set saldo',
            onPressed: onSetBalance,
          ),
          IconButton(
            icon: Icon(Icons.drive_file_rename_outline, size: 18, color: c.textMain),
            tooltip: 'Ganti nama/jenis',
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: c.red),
            tooltip: 'Hapus',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Kartu rekap pemasukan/pengeluaran/selisih untuk satu rentang waktu.
/// ─────────────────────────────────────────────────────────────
class HistorySummaryCard extends StatelessWidget {
  final String title;
  final double income;
  final double expense;
  const HistorySummaryCard({
    super.key,
    required this.title,
    required this.income,
    required this.expense,
  });

  Widget _stat(BuildContext context, String label, double v, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
            const SizedBox(height: 2),
            Text(fmt(v),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final net = income - expense;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: c.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              _stat(context, 'Pemasukan', income, c.green),
              _stat(context, 'Pengeluaran', expense, c.red),
              _stat(context, 'Selisih', net, net >= 0 ? c.green : c.red),
            ],
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Chart batang harian sederhana: pemasukan (hijau) vs pengeluaran (merah)
/// ─────────────────────────────────────────────────────────────
class DailyBarChart extends StatelessWidget {
  final List<DayGroup> days; // urut TERLAMA -> TERBARU
  const DailyBarChart({super.key, required this.days});

  Widget _legendDot(BuildContext context, Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final c = context.colors;

    double maxVal = 0;
    for (final d in days) {
      if (d.income > maxVal) maxVal = d.income;
      if (d.expense > maxVal) maxVal = d.expense;
    }
    const barMaxHeight = 64.0;
    double h(double v) => maxVal > 0 ? (v / maxVal) * barMaxHeight : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legendDot(context, c.green, 'Masuk'),
              const SizedBox(width: 12),
              _legendDot(context, c.red, 'Keluar'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: barMaxHeight + 26,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true, // langsung tergulir ke hari paling baru
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days.map((d) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Tooltip(
                          message:
                              '${fmtTanggalPendek(d.date)}\nMasuk: ${fmt(d.income)}\nKeluar: ${fmt(d.expense)}',
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: h(d.income).clamp(1.5, barMaxHeight),
                                decoration: BoxDecoration(
                                  color: c.green,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Container(
                                width: 6,
                                height: h(d.expense).clamp(1.5, barMaxHeight),
                                decoration: BoxDecoration(
                                  color: c.red,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(fmtTanggalPendek(d.date),
                            style: TextStyle(fontSize: 8, color: c.textMuted)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
