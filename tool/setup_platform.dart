// Jalankan dari root project Flutter (sesudah `flutter create`):
//   dart run tool/setup_platform.dart
//
// Yang dikerjakan:
//  - Nama aplikasi di HP menjadi "WanderGeo" (Android + iOS)
//  - Android: izin INTERNET (font & Supabase di build release) dan USE_BIOMETRIC,
//    MainActivity memakai FlutterFragmentActivity (wajib untuk local_auth)
//  - iOS: NSFaceIDUsageDescription untuk login wajah
import 'dart:io';

const appName = 'WanderGeo';

void main() {
  _patchAndroidManifest();
  _patchMainActivity();
  _patchInfoPlist();
  stdout.writeln('\nSelesai. Lanjutkan dengan: dart run flutter_launcher_icons');
}

void _patchAndroidManifest() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stdout.writeln('! AndroidManifest.xml tidak ditemukan (dilewati)');
    return;
  }
  var s = f.readAsStringSync();
  s = s.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="$appName"');
  for (final perm in ['INTERNET', 'USE_BIOMETRIC']) {
    if (!s.contains('android.permission.$perm')) {
      s = s.replaceFirst(
        '<application',
        '<uses-permission android:name="android.permission.$perm"/>\n    <application',
      );
    }
  }
  f.writeAsStringSync(s);
  stdout.writeln('✓ AndroidManifest.xml');
}

void _patchMainActivity() {
  final dir = Directory('android/app/src/main');
  if (!dir.existsSync()) return;
  for (final e in dir.listSync(recursive: true)) {
    if (e is! File) continue;
    if (!e.path.endsWith('MainActivity.kt') && !e.path.endsWith('MainActivity.java')) continue;
    final s = e.readAsStringSync();
    if (!s.contains('FlutterFragmentActivity')) {
      e.writeAsStringSync(s.replaceAll('FlutterActivity', 'FlutterFragmentActivity'));
    }
    stdout.writeln('✓ ${e.path.split('/').last}');
    return;
  }
}

String _setPlistString(String plist, String key, String value) {
  final re = RegExp('<key>$key</key>\\s*<string>[^<]*</string>');
  final entry = '<key>$key</key>\n\t<string>$value</string>';
  if (re.hasMatch(plist)) return plist.replaceFirst(re, entry);
  final end = plist.lastIndexOf('</dict>');
  return '${plist.substring(0, end)}\t$entry\n${plist.substring(end)}';
}

void _patchInfoPlist() {
  final f = File('ios/Runner/Info.plist');
  if (!f.existsSync()) {
    stdout.writeln('! Info.plist tidak ditemukan (dilewati)');
    return;
  }
  var s = f.readAsStringSync();
  s = _setPlistString(s, 'CFBundleDisplayName', appName);
  s = _setPlistString(s, 'CFBundleName', appName);
  s = _setPlistString(
    s,
    'NSFaceIDUsageDescription',
    'Dipakai untuk membuka Paspor Agen dengan wajah.',
  );
  f.writeAsStringSync(s);
  stdout.writeln('✓ Info.plist');
}
