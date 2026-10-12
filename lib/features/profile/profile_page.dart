import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/services/profile_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/round_icon_button.dart';
import '../auth/auth_repository.dart';

/// Profil: foto, nama, gelar, progres paspor, dan akun.
///
/// Semua data teks berasal dari database lewat [AuthRepository]:
/// - nama, username, email, gelar -> tabel `users`
/// - jumlah negara selesai/terbuka/terkunci + total skor -> `user_progress`
/// Nama tampilan bisa diubah dan tersimpan di database. Foto disimpan lokal
/// per akun lewat [ProfileService]; bila belum ada foto lokal dan `avatar_url`
/// di database terisi, foto dari URL itu yang ditampilkan.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _service = ProfileService();
  late final AuthRepository _repo = context.read<AuthRepository>();

  AuthUser? _user;
  ProfileStats? _stats;
  Uint8List? _photo;
  int _photoVersion = 0; // memaksa gambar dibangun ulang saat foto berganti

  bool _loading = true;
  bool _busy = false; // sedang memproses foto
  bool _savingName = false;
  String? _error;

  // Id user dari sesi; 'tamu' hanya cadangan bila sesi belum ada.
  String get _userId => _user?.id ?? 'tamu';
  String get _name => _user?.displayName ?? 'Petualang WanderGeo';

  @override
  void initState() {
    super.initState();
    _user = _repo.currentUser;
    _loadPhoto();
    _refresh();
  }

  Future<void> _loadPhoto() async {
    try {
      final photo = await _service.readPhoto(_userId);
      if (!mounted) return;
      setState(() => _photo = photo);
    } catch (_) {
      // Foto lokal tidak bisa dibaca: tampilkan huruf awal saja.
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await _repo.fetchProfile();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _user = r.user ?? _user;
        _stats = r.stats ?? _stats;
      } else {
        _error = r.message;
      }
    });
  }

  // ---------- aksi ----------

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
  }

  Future<void> _choosePhotoSource() async {
    HapticFeedback.selectionClick();
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Foto profil', style: AppTheme.heading(18)),
              const SizedBox(height: 6),
              // Kamera tidak tersedia andal di browser desktop.
              if (!kIsWeb)
                _sheetTile(
                  ctx,
                  Icons.photo_camera_rounded,
                  'Ambil dengan kamera',
                  _PhotoAction.camera,
                ),
              _sheetTile(
                ctx,
                Icons.photo_library_rounded,
                'Pilih dari galeri',
                _PhotoAction.gallery,
              ),
              if (_photo != null)
                _sheetTile(
                  ctx,
                  Icons.delete_outline_rounded,
                  'Hapus foto',
                  _PhotoAction.remove,
                  color: AppColors.error,
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null) return;

    setState(() => _busy = true);
    try {
      switch (action) {
        case _PhotoAction.camera:
          await _pick(ImageSource.camera);
        case _PhotoAction.gallery:
          await _pick(ImageSource.gallery);
        case _PhotoAction.remove:
          await _service.removePhoto(_userId);
          if (mounted) setState(() => _photo = null);
      }
    } on PlatformException {
      _toast('Tidak bisa mengakses kamera atau galeri. Periksa izin aplikasi.');
    } catch (_) {
      _toast('Foto gagal diperbarui. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    final bytes = await _service.pickPhoto(_userId, source);
    if (bytes == null || !mounted) return;
    setState(() {
      _photo = bytes;
      _photoVersion++;
    });
    _toast(kIsWeb
        ? 'Foto diganti (di browser, foto hilang saat halaman dimuat ulang)'
        : 'Foto profil diperbarui');
  }

  Widget _sheetTile(
    BuildContext ctx,
    IconData icon,
    String label,
    _PhotoAction value, {
    Color color = AppColors.ink,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color == AppColors.ink ? AppColors.teal : color),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  Future<void> _editName() async {
    if (_savingName) return;
    HapticFeedback.selectionClick();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initial: _user?.fullName ?? ''),
    );
    if (result == null || !mounted) return;
    if (result == (_user?.fullName ?? '')) return; // tidak ada perubahan

    setState(() => _savingName = true);
    final r = await _repo.updateFullName(result);
    if (!mounted) return;
    setState(() {
      _savingName = false;
      if (r.ok && r.user != null) _user = r.user;
    });
    _toast(r.ok ? 'Nama diperbarui' : (r.message ?? 'Nama gagal disimpan'));
  }

  // ---------- tampilan ----------

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navSpace = 92 + mq.padding.bottom;

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _refresh,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding:
              EdgeInsets.fromLTRB(20, mq.padding.top + 8, 20, navSpace + 24),
          children: [
            _header(),
            const SizedBox(height: 16),
            _hero(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _errorCard(_error!),
            ],
            const SizedBox(height: 14),
            _statsRow(_stats),
            const SizedBox(height: 22),
            Text('Akun', style: AppTheme.heading(16)),
            const SizedBox(height: 10),
            _settings(),
            const SizedBox(height: 22),
            const Center(
              child: Text(
                'WanderGeo v1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.hint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profil', style: AppTheme.heading(26)),
              const SizedBox(height: 2),
              const Text(
                'Identitas dan progres petualanganmu',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
        RoundIconButton(
          icon: Icons.refresh_rounded,
          label: 'Muat ulang',
          onTap: _loading ? () {} : _refresh,
        ),
      ],
    );
  }

  Widget _hero() {
    final s = _stats;
    final progress = (s != null && s.total > 0) ? s.selesai / s.total : 0.0;
    final progressText = (s != null && s.total > 0)
        ? '${s.selesai} dari ${s.total} negara'
        : (_loading ? 'Memuat…' : '–');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepNavy, AppColors.ink],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -46,
            right: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.teal.withOpacity(.28),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightTeal.withOpacity(.10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  _avatar(),
                  const SizedBox(height: 14),
                  Text(
                    _name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTheme.heading(22, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(
                        icon: Icons.workspace_premium_rounded,
                        label: _user?.title ?? 'Petualang Pemula',
                        bg: Colors.white,
                        fg: AppColors.goldDark,
                        iconColor: AppColors.gold,
                      ),
                      if (_user != null)
                        _pill(
                          icon: Icons.alternate_email_rounded,
                          label: _user!.username,
                          bg: Colors.white.withOpacity(.14),
                          fg: AppColors.lightTeal,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        'Progres paspor',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        progressText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(.75),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(.16),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.gold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    const size = 104.0;
    final initial = _name.trim().isEmpty ? 'W' : _name.trim()[0].toUpperCase();
    return Semantics(
      button: true,
      label: 'Ganti foto profil',
      child: GestureDetector(
        onTap: _busy ? null : _choosePhotoSource,
        child: SizedBox(
          width: size + 8,
          height: size + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size + 8,
                height: size + 8,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.gold, AppColors.goldDeep],
                  ),
                ),
                child: ClipOval(child: _avatarImage(initial)),
              ),
              if (_busy)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.ink.withOpacity(.45),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withOpacity(.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 18,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Urutan: foto lokal -> avatar_url dari database -> huruf awal nama.
  Widget _avatarImage(String initial) {
    final photo = _photo;
    if (photo != null) {
      return Image.memory(
        photo,
        key: ValueKey(_photoVersion),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _initial(initial),
      );
    }
    final url = _user?.avatarUrl;
    if (url != null && url.trim().isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initial(initial),
      );
    }
    return _initial(initial);
  }

  Widget _initial(String letter) {
    return Container(
      color: AppColors.sea,
      alignment: Alignment.center,
      child: Text(letter, style: AppTheme.heading(42, color: AppColors.teal)),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    Color? iconColor,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEBE9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 22, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : _refresh,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(ProfileStats? s) {
    String v(int? n) => n == null ? '–' : '$n';
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.verified_rounded,
            color: AppColors.success,
            value: v(s?.selesai),
            label: 'Selesai',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.lock_open_rounded,
            color: AppColors.teal,
            value: v(s?.terbuka),
            label: 'Terbuka',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.emoji_events_rounded,
            color: AppColors.goldDeep,
            value: v(s?.totalScore),
            label: 'Total skor',
          ),
        ),
      ],
    );
  }

  Widget _settings() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _SettingTile(
            icon: Icons.badge_outlined,
            title: 'Nama tampilan',
            subtitle: _savingName ? 'Menyimpan…' : _name,
            onTap: _savingName ? null : _editName,
          ),
          const _TileDivider(),
          _SettingTile(
            icon: Icons.alternate_email_rounded,
            title: 'Username',
            subtitle: _user?.username ?? '–',
          ),
          const _TileDivider(),
          _SettingTile(
            icon: Icons.mail_outline_rounded,
            title: 'Email',
            subtitle: _user?.email ?? '–',
          ),
          const _TileDivider(),
          _SettingTile(
            icon: Icons.photo_camera_outlined,
            title: 'Foto profil',
            subtitle:
                _photo == null ? 'Belum ada foto' : 'Ketuk untuk mengganti',
            onTap: _busy ? null : _choosePhotoSource,
          ),
          const _TileDivider(),
          const _SettingTile(
            icon: Icons.fingerprint_rounded,
            title: 'Login biometrik',
            subtitle: 'Sidik jari atau wajah membuka sesi yang tersimpan',
          ),
        ],
      ),
    );
  }
}

enum _PhotoAction { camera, gallery, remove }

/// Dialog ubah nama. Dibuat sebagai widget sendiri agar controller-nya
/// di-dispose tepat setelah dialog benar-benar tertutup.
class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.length < 2) {
      setState(() => _error = 'Nama minimal 2 karakter');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Nama tampilan', style: AppTheme.heading(18)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Nama lengkap',
          errorText: _error,
          filled: true,
          fillColor: AppColors.field,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 10),
          Text(value, style: AppTheme.heading(22)),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.sea,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 21, color: AppColors.teal),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
          ],
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 1,
        indent: 70,
        color: AppColors.border,
      );
}