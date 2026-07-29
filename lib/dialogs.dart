import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'logic.dart';
import 'theme.dart';

double? _parseRupiah(String s) {
  final cleaned = s.replaceAll('.', '').replaceAll(',', '').trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

Future<bool> showConfirmDialog(BuildContext context, {required String title, required String message}) async {
  final res = await showDialog<bool>(
    context: context,
    // Tanpa backgroundColor kustom: AlertDialog M3 otomatis pakai
    // colorScheme.surfaceContainerHigh sesuai spesifikasi Material 3.
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya')),
      ],
    ),
  );
  return res ?? false;
}

Future<void> showInfoDialog(BuildContext context, {required String title, required String message, Color? color}) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: TextStyle(color: color ?? context.colors.textMain)),
      content: SingleChildScrollView(child: Text(message)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}

/// Dialog input jumlah (+ opsional catatan) — dipakai untuk Uang Masuk,
/// Pengeluaran, Set Saldo, Pemasukan tambahan.
Future<Map<String, dynamic>?> showAmountDialog(
  BuildContext context, {
  required String title,
  String? initialAmount,
  bool withNote = true,
  String noteLabel = 'Catatan',
  String noteHint = '',
}) async {
  final amtCtrl = TextEditingController(text: initialAmount ?? '');
  final noteCtrl = TextEditingController(text: noteHint);

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amtCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
          ),
          if (withNote) ...[
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: noteLabel),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () {
            final amt = _parseRupiah(amtCtrl.text);
            if (amt == null) {
              showInfoDialog(ctx, title: 'Error', message: 'Jumlah tidak valid', color: ctx.colors.red);
              return;
            }
            Navigator.pop(ctx, {'amount': amt, 'note': noteCtrl.text.trim()});
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}

/// Dialog input gaji dengan info tabungan/bisa-pakai yang update live.
Future<double?> showSalaryDialog(BuildContext context, EmployedData d) async {
  final ctrl = TextEditingController(text: d.salary > 0 ? d.salary.toStringAsFixed(0) : '');
  return showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final amt = _parseRupiah(ctrl.text) ?? 0;
      final sav = amt * d.savingsPercent / 100;
      return AlertDialog(
        title: const Text('Input Gaji', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Jumlah Gaji (Rp)'),
            ),
            const SizedBox(height: 8),
            Text('Tabungan: ${fmt(sav)}  |  Bisa pakai: ${fmt(amt - sav)}',
                style: TextStyle(fontSize: 11, color: ctx.colors.textMuted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final v = _parseRupiah(ctrl.text);
              if (v == null) {
                showInfoDialog(ctx, title: 'Error', message: 'Jumlah tidak valid', color: ctx.colors.red);
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('Simpan'),
          ),
        ],
      );
    }),
  );
}

const _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// Dialog tambah/edit pos alokasi/operasional — meniru AllocDialog Python
/// (pilihan frekuensi: tiap hari / per periode / selang minggu).
Future<AllocItem?> showAllocFormDialog(BuildContext context, {required String mode, AllocItem? item}) async {
  final isEdit = item != null;
  final nameCtrl = TextEditingController(text: item?.label ?? '');
  final amtCtrl = TextEditingController(text: item != null ? item.amount.toStringAsFixed(0) : '');
  final freqCountCtrl = TextEditingController(text: (item?.freqCount ?? 1).toString());
  final bwWeeksCtrl = TextEditingController(text: (item?.biweeklyWeeks ?? 2).toString());

  String freq = item?.freq ?? 'daily';
  final selectedDays = <int>{...(item?.days ?? List.generate(7, (i) => i))};
  final selectedBwDays = <int>{...(item?.biweeklyDays ?? [4])};
  bool priority = item?.priority ?? false;
  bool variableAmount = item?.variableAmount ?? false;

  return showDialog<AllocItem>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(isEdit ? 'Edit: ${item.label}' : 'Tambah Pos', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama pos:', style: TextStyle(fontSize: 11, color: ctx.colors.textMuted)),
              TextField(controller: nameCtrl),
              const SizedBox(height: 10),
              Text('Jumlah (Rp):', style: TextStyle(fontSize: 11, color: ctx.colors.textMuted)),
              TextField(controller: amtCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              Text('Frekuensi:', style: TextStyle(fontSize: 11, color: ctx.colors.textMuted)),
              Wrap(
                spacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('Tiap hari'),
                    selected: freq == 'daily',
                    onSelected: (_) => setState(() => freq = 'daily'),
                  ),
                  ChoiceChip(
                    label: const Text('Per periode'),
                    selected: freq == 'period',
                    onSelected: (_) => setState(() => freq = 'period'),
                  ),
                  ChoiceChip(
                    label: const Text('Selang minggu'),
                    selected: freq == 'biweekly',
                    onSelected: (_) => setState(() => freq = 'biweekly'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (freq == 'daily') ...[
                Text('Aktif pada hari:', style: TextStyle(fontSize: 11, color: ctx.colors.textMuted)),
                Wrap(
                  spacing: 4,
                  children: List.generate(7, (i) {
                    return FilterChip(
                      label: Text(_dayNames[i]),
                      selected: selectedDays.contains(i),
                      onSelected: (v) => setState(() => v ? selectedDays.add(i) : selectedDays.remove(i)),
                    );
                  }),
                ),
              ],
              if (freq == 'period') ...[
                Text('Berapa kali per periode:', style: TextStyle(fontSize: 11, color: ctx.colors.textMuted)),
                SizedBox(
                  width: 100,
                  child: TextField(controller: freqCountCtrl, keyboardType: TextInputType.number),
                ),
              ],
              if (freq == 'biweekly') ...[
                Text('Setiap berapa minggu:', style: TextStyle(fontSize: 11, color: ctx.colors.textMuted)),
                SizedBox(
                  width: 80,
                  child: TextField(controller: bwWeeksCtrl, keyboardType: TextInputType.number),
                ),
                const SizedBox(height: 6),
                Text('Pada hari:', style: TextStyle(fontSize: 11, color: ctx.colors.textMuted)),
                Wrap(
                  spacing: 4,
                  children: List.generate(7, (i) {
                    return FilterChip(
                      label: Text(_dayNames[i]),
                      selected: selectedBwDays.contains(i),
                      onSelected: (v) => setState(() => v ? selectedBwDays.add(i) : selectedBwDays.remove(i)),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Harga pos ini bisa berubah-ubah (mis. kuota, promo)',
                    style: TextStyle(fontSize: 12)),
                subtitle: Text(
                    'Tiap dicentang, kamu akan diminta isi jumlah real saat itu.\nJumlah di atas tetap jadi jatah/acuan default.',
                    style: TextStyle(fontSize: 10, color: ctx.colors.textMuted)),
                value: variableAmount,
                onChanged: (v) => setState(() => variableAmount = v ?? false),
              ),
              if (mode == 'employed') ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Pos ini prioritas (tidak hilang saat saldo terbatas)',
                      style: TextStyle(fontSize: 12)),
                  value: priority,
                  onChanged: (v) => setState(() => priority = v ?? false),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final amt = _parseRupiah(amtCtrl.text);
              if (name.isEmpty || amt == null) {
                showInfoDialog(ctx, title: 'Error', message: 'Data tidak valid', color: ctx.colors.red);
                return;
              }
              final result = AllocItem(
                id: item?.id ?? const Uuid().v4().substring(0, 8),
                label: name,
                amount: amt,
                freq: freq,
                days: freq == 'daily' ? selectedDays.toList() : null,
                freqCount: freq == 'period' ? (int.tryParse(freqCountCtrl.text) ?? 1) : 1,
                biweeklyWeeks: freq == 'biweekly' ? (int.tryParse(bwWeeksCtrl.text) ?? 2) : 2,
                biweeklyDays: freq == 'biweekly' ? selectedBwDays.toList() : [4],
                biweeklyAnchor: item?.biweeklyAnchor,
                priority: mode == 'employed' ? priority : false,
                variableAmount: variableAmount,
                recentAmounts: item?.recentAmounts,
              );
              Navigator.pop(ctx, result);
            },
            child: Text(isEdit ? 'Simpan' : 'Tambah'),
          ),
        ],
      );
    }),
  );
}
