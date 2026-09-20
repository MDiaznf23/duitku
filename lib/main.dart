import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models.dart';
import 'logic.dart';
import 'theme.dart';
import 'screens/beranda_tab.dart';
import 'screens/alokasi_tab.dart';
import 'screens/riwayat_tab.dart';
import 'screens/pengaturan_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const DuitKuApp());
}

class DuitKuApp extends StatelessWidget {
  const DuitKuApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuitKu',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppData? data;
  int tabIndex = 0;
  Timer? _timer;
  String _currentDate = todayStr();

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (todayStr() != _currentDate) {
        _currentDate = todayStr();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await Store.load();
    if (mounted) setState(() => data = d);
  }

  Future<void> _refresh() async {
    if (data != null) await Store.save(data!);
    if (mounted) setState(() {});
  }

  Future<void> _importData(AppData newData) async {
    await Store.save(newData);
    if (mounted) setState(() => data = newData);
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mode = data!.mode;
    final modeLabel = mode == 'unemployed' ? 'Pengangguran' : 'Bekerja';
    final modeColor = mode == 'unemployed' ? context.colors.tertiary : context.colors.secondary;
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    final tabs = [
      BerandaTab(data: data!, onChanged: _refresh),
      AlokasiTab(data: data!, onChanged: _refresh),
      RiwayatTab(data: data!, onChanged: _refresh),
      PengaturanTab(data: data!, onChanged: _refresh, onImport: _importData),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('💰 DuitKu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(border: Border.all(color: modeColor), borderRadius: BorderRadius.circular(4)),
              child: Text(modeLabel, style: TextStyle(fontSize: 10, color: modeColor)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text(dateStr, style: TextStyle(fontSize: 11, color: context.colors.textMuted))),
          ),
        ],
      ),
      body: IndexedStack(index: tabIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (i) => setState(() => tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Alokasi'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Pengaturan'),
        ],
      ),
    );
  }
}
