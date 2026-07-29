import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../models.dart';
import '../logic.dart';
import '../theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';
import '../import_export.dart';

class PengaturanTab extends StatelessWidget {
  final AppData data;
  final Future<void> Function() onChanged;
  final Future<void> Function(AppData) onImport;
  const PengaturanTab({super.key, required this.data, required this.onChanged, required this.onImport});

  Widget _card(BuildContext context, {required Widget child}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.colors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.colors.border)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final cur = data.mode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Mode Profil'),
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pilih sesuai kondisi kamu sekarang.', style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: cur == 'unemployed' ? context.colors.accent : context.colors.muted,
                          foregroundColor: cur == 'unemployed' ? context.colors.onAccent : context.colors.textMuted,
                        ),
                        onPressed: () async {
                          if (data.mode != 'unemployed') {
                            data.mode = 'unemployed';
                            await onChanged();
                          }
                        },
                        child: const Text('Pengangguran'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: cur == 'employed' ? context.colors.accent : context.colors.muted,
                          foregroundColor: cur == 'employed' ? context.colors.onAccent : context.colors.textMuted,
                        ),
                        onPressed: () async {
                          if (data.mode != 'employed') {
                            data.mode = 'employed';
                            await onChanged();
                          }
                        },
                        child: const Text('Bekerja'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Aktif sekarang: ${cur == "unemployed" ? "Pengangguran" : "Bekerja"}',
                    style: TextStyle(color: context.colors.green, fontSize: 11)),
              ],
            ),
          ),
          if (cur == 'employed') ..._buildSalaryConfig(context),
          const SectionTitle('Backup & Pindah Data'),
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export untuk membawa data (saldo, pos, riwayat) dari HP/komputer ini '
                  'ke perangkat lain. Import untuk memuat file data.json dari versi '
                  'desktop atau HP lain — data yang sedang aktif di HP ini akan ditimpa.',
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionButton(
                      label: 'Export Data',
                      color: context.colors.accentDark,
                      foreground: context.colors.onAccentDark,
                      onPressed: () async {
                        try {
                          final path = await ImportExport.exportData(data);
                          if (path == null) return; // user batal
                          if (context.mounted) {
                            final msg = Platform.isAndroid
                                ? 'Data berhasil disimpan di lokasi yang kamu pilih.'
                                : 'Data tersimpan di:\n$path';
                            await showInfoDialog(context,
                                title: 'Berhasil', message: msg, color: context.colors.green);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            await showInfoDialog(context,
                                title: 'Gagal Export', message: '$e', color: context.colors.red);
                          }
                        }
                      },
                    ),
                    ActionButton(
                      label: 'Import Data',
                      color: context.colors.muted,
                      foreground: context.colors.onMuted,
                      onPressed: () async {
                        try {
                          final imported = await ImportExport.pickAndParseImportFile();
                          if (imported == null) return; // user batal pilih file
                          if (!context.mounted) return;
                          final ok = await showConfirmDialog(
                            context,
                            title: 'Import Data',
                            message:
                                'Data yang sedang aktif di HP ini akan DITIMPA dengan isi '
                                'file yang kamu pilih.\n\nLanjutkan?',
                          );
                          if (!ok) return;
                          await onImport(imported);
                          if (context.mounted) {
                            await showInfoDialog(context,
                                title: 'Berhasil',
                                message: 'Data berhasil diimport.',
                                color: context.colors.green);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            await showInfoDialog(context,
                                title: 'Gagal Import', message: '$e', color: context.colors.red);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionTitle('Reset'),
          _card(
            context,
            child: Builder(
              builder: (context) {
                final resetButtons = <Widget>[
                  ActionButton(
                    label: 'Reset Hari Ini',
                    color: context.colors.muted,
                    foreground: context.colors.onMuted,
                    onPressed: () async {
                      final ok = await showConfirmDialog(context,
                          title: 'Reset', message: 'Reset checklist hari ini?\nSaldo akan dikembalikan.');
                      if (ok) {
                        resetToday(data);
                        await onChanged();
                      }
                    },
                  ),
                  if (cur == 'employed') ...[
                    ActionButton(
                      label: 'Reset Saldo',
                      color: context.colors.red,
                      foreground: context.colors.onRed,
                      outlined: true,
                      onPressed: () async {
                        final ok = await showConfirmDialog(context,
                            title: 'Reset Saldo',
                            message: 'Reset saldo ke 0?\n\nIni akan menghapus semua riwayat income\ndan mereset saldo menjadi Rp 0.');
                        if (ok) {
                          resetSaldoEmployed(data);
                          await onChanged();
                        }
                      },
                    ),
                    ActionButton(
                      label: 'Reset Riwayat',
                      color: context.colors.muted,
                      foreground: context.colors.onMuted,
                      onPressed: () async {
                        final ok = await showConfirmDialog(context,
                            title: 'Reset Riwayat', message: 'Hapus semua riwayat transaksi?\nSaldo tidak akan berubah.');
                        if (ok) {
                          resetHistoryEmployed(data);
                          await onChanged();
                        }
                      },
                    ),
                  ],
                  ActionButton(
                    label: 'Reset Total',
                    color: context.colors.red,
                    foreground: context.colors.onRed,
                    outlined: true,
                    onPressed: () async {
                      final msg = cur == 'unemployed'
                          ? 'Reset semua ke awal?\n\n• Saldo → 0\n• Riwayat → bersih\n• Checklist bulan ini → bersih\n\nAksi ini tidak bisa dibatalkan.'
                          : 'Reset semua ke awal?\n\n• Saldo → 0\n• Riwayat → bersih\n• Periode gaji → mulai ulang\n• Checklist hari ini → bersih\n\nAksi ini tidak bisa dibatalkan.';
                      final ok = await showConfirmDialog(context, title: 'Reset Total', message: msg);
                      if (ok) {
                        if (cur == 'unemployed') {
                          resetAllUnemployed(data);
                        } else {
                          resetAllEmployed(data);
                        }
                        await onChanged();
                      }
                    },
                  ),
                ];

                // Susun jadi grid 2 kolom yang lebar tiap tombolnya sama,
                // supaya simetris dan tidak menyisakan ruang kosong.
                final rows = <Widget>[];
                for (var i = 0; i < resetButtons.length; i += 2) {
                  final hasSecond = i + 1 < resetButtons.length;
                  rows.add(
                    Padding(
                      padding: EdgeInsets.only(bottom: i + 2 < resetButtons.length ? 8 : 0),
                      child: Row(
                        children: [
                          Expanded(child: resetButtons[i]),
                          if (hasSecond) ...[
                            const SizedBox(width: 8),
                            Expanded(child: resetButtons[i + 1]),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
              },
            ),
          ),
          const SectionTitle('Tentang'),
          _card(
            context,
            child: Text('DuitKu v2.0 (Flutter) — data disimpan lokal di data.json pada penyimpanan aplikasi.',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSalaryConfig(BuildContext context) {
    final d = data.employed;
    return [
      const SectionTitle('Pengaturan Gaji'),
      _card(
        context,
        child: Column(
          children: [
            _cfgRow(context, 'Gaji (Rp)', d.salary.toStringAsFixed(0), (v) => d.salary = v),
            const SizedBox(height: 8),
            _cfgRow(context, 'Periode (hari)', d.salaryPeriodDays.toString(), (v) => d.salaryPeriodDays = v.toInt()),
            const SizedBox(height: 8),
            _cfgRow(context, 'Tabungan (%)', d.savingsPercent.toStringAsFixed(0), (v) => d.savingsPercent = v),
          ],
        ),
      ),
    ];
  }

  Widget _cfgRow(BuildContext context, String label, String value, void Function(double) onSave) {
    final ctrl = TextEditingController(text: value);
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 12, color: context.colors.textMuted))),
        Expanded(
          child: TextField(controller: ctrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.accentDark,
              foregroundColor: context.colors.onAccentDark,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () async {
              final v = double.tryParse(ctrl.text.replaceAll('.', '').replaceAll(',', ''));
              if (v == null) {
                await showInfoDialog(context, title: 'Error', message: 'Nilai tidak valid', color: context.colors.red);
                return;
              }
              onSave(v);
              await onChanged();
              final warn = warnIfOperasionalOverlimit(data);
              if (warn != null && context.mounted) {
                await showInfoDialog(context, title: 'Operasional Melebihi Gaji', message: warn, color: context.colors.yellow);
              }
            },
            child: const Text('OK'),
          ),
        ),
      ],
    );
  }
}
