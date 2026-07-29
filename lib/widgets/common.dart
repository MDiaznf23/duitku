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
  const HistoryRowTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type == 'income';
    final color = isIncome ? context.colors.green : context.colors.red;
    final sign = isIncome ? '+' : '-';
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
            child: Text(entry.note,
                style: TextStyle(fontSize: 12, color: context.colors.textMain),
                overflow: TextOverflow.ellipsis),
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
      // Untuk aksi berisiko (mis. reset) tapi tidak perlu seheboh blok solid:
      // border + teks berwarna, latar tetap netral senada kartu.
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
