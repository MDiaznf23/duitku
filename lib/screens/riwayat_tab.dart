import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class RiwayatTab extends StatelessWidget {
  final AppData data;
  const RiwayatTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final history = data.mode == 'unemployed' ? data.unemployed.history : data.employed.history;
    final items = history.reversed.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Riwayat Transaksi'),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Belum ada riwayat', style: TextStyle(color: context.colors.textMuted)),
            )
          else
            ...items.map((h) => HistoryRowTile(entry: h)),
        ],
      ),
    );
  }
}
