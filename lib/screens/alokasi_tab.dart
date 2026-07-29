import 'package:flutter/material.dart';
import '../models.dart';
import '../logic.dart';
import '../theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';

class AlokasiTab extends StatelessWidget {
  final AppData data;
  final Future<void> Function() onChanged;
  const AlokasiTab({super.key, required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final mode = data.mode;
    final items = mode == 'unemployed' ? data.unemployed.dailyAllocations : data.employed.operationals;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(mode == 'unemployed' ? 'Kelola Alokasi' : 'Pos Operasional'),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Belum ada pos. Tambah lewat tombol di bawah.', style: TextStyle(color: context.colors.textMuted)),
              )
            else
              ...items.map((item) => AllocRowTile(
                    item: item,
                    onEdit: () async {
                      final result = await showAllocFormDialog(context, mode: mode, item: item);
                      if (result != null) {
                        final idx = items.indexWhere((i) => i.id == item.id);
                        if (idx != -1) items[idx] = result;
                        await onChanged();
                        if (mode == 'employed') {
                          final warn = warnIfOperasionalOverlimit(data);
                          if (warn != null && context.mounted) {
                            await showInfoDialog(context, title: 'Operasional Melebihi Gaji', message: warn, color: context.colors.yellow);
                          }
                        }
                      }
                    },
                    onDelete: () async {
                      final ok = await showConfirmDialog(context, title: 'Hapus', message: 'Hapus pos ini?');
                      if (ok) {
                        items.removeWhere((i) => i.id == item.id);
                        await onChanged();
                      }
                    },
                  )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.colors.accentDark,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Pos'),
        onPressed: () async {
          final result = await showAllocFormDialog(context, mode: mode);
          if (result != null) {
            items.add(result);
            await onChanged();
            if (mode == 'employed') {
              final warn = warnIfOperasionalOverlimit(data);
              if (warn != null && context.mounted) {
                await showInfoDialog(context, title: 'Operasional Melebihi Gaji', message: warn, color: context.colors.yellow);
              }
            }
          }
        },
      ),
    );
  }
}
