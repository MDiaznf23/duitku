import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'models.dart';

/// ─────────────────────────────────────────────────────────────
/// Import / Export data.json
///
/// Export: minta user pilih lokasi + nama file lewat dialog "Save As"
///
/// Import: buka file picker, user pilih file .json 
/// ─────────────────────────────────────────────────────────────
class ImportExport {
  static String _timestampName() {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'duitku_export_${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}.json';
  }

  /// Export [data] ke file .json lewat dialog "Save As" bawaan OS.
  /// Return path file yang tersimpan, atau null kalau user batal.
  static Future<String?> exportData(AppData data) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan backup DuitKu',
      fileName: _timestampName(),
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes, // dipakai file_picker utk langsung menulis isinya
    );
    if (savedPath == null) return null; // user batal

    // Jaga-jaga: di sebagian versi/OS, saveFile hanya mengembalikan path
    // pilihan tanpa benar-benar menulis isinya kalau path itu adalah
    // path file biasa (bukan content:// URI Android/iOS). Tulis ulang
    // supaya pasti tersimpan.
    try {
      final f = File(savedPath);
      final existing = await f.exists() ? await f.readAsBytes() : null;
      if (existing == null || existing.isEmpty) {
        await f.writeAsBytes(bytes);
      }
    } catch (_) {

    }

    return savedPath;
  }

  /// Buka file picker untuk pilih file .json, lalu parse jadi AppData.
  static Future<AppData?> pickAndParseImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null; // user batal

    final picked = result.files.single;
    String content;
    if (picked.bytes != null) {
      content = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      content = await File(picked.path!).readAsString();
    } else {
      throw Exception('File tidak bisa dibaca dari perangkat ini');
    }

    late final dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      throw Exception('File bukan JSON yang valid');
    }

    if (decoded is! Map<String, dynamic> ||
        !decoded.containsKey('mode') ||
        !decoded.containsKey('unemployed') ||
        !decoded.containsKey('employed')) {
      throw Exception('File ini bukan data DuitKu (format tidak cocok)');
    }

    try {
      return AppData.fromJson(decoded);
    } catch (e) {
      throw Exception('Isi file tidak lengkap / rusak: $e');
    }
  }
}
