import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/teledrive_api.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'file_preview_screen.dart';
import 'sync_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _folderId = 0;
  final List<TeleFolder> _stack = [];
  FolderContent? _content;
  DashboardStats? _stats;
  List<TeleFile>? _searchResults;
  String _searchQuery = '';
  String _category = 'Semua';
  bool _loading = false;
  bool _telegramDown = false;
  bool _gridView = false;
  String? _error;

  static const categories = [
    'Semua',
    'Image',
    'Document',
    'Audio',
    'Video',
    'Archive',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String get _folderName => _stack.isEmpty ? 'Root' : _stack.last.name;

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
      _telegramDown = false;
    });
    try {
      final results = await Future.wait([
        api.getContent(_folderId),
        api.getDashboard(),
      ]);
      if (!mounted) return;
      setState(() {
        _content = results[0] as FolderContent;
        _stats = results[1] as DashboardStats;
      });
      // Kalau sedang di tampilan filter/pencarian, segarkan juga daftar
      // yang sedang tampil — kalau tidak, daftar lama yang tetap dipakai
      // dan perubahan (mis. file terhapus) tidak kelihatan.
      await _refetchActiveList();
    } on TelegramDisconnectedException {
      if (mounted) setState(() => _telegramDown = true);
    } on AuthException {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadContentOnly() async {
    try {
      final c = await api.getContent(_folderId);
      if (mounted) setState(() => _content = c);
    } on TelegramDisconnectedException {
      if (mounted) setState(() => _telegramDown = true);
    } on AuthException {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Mengambil ulang daftar yang sedang tampil (hasil pencarian atau
  /// filter kategori). Tanpa ini, _searchResults lama terus dipakai dan
  /// hapus/extract/upload tampak tidak berpengaruh.
  Future<void> _refetchActiveList() async {
    try {
      if (_searchQuery.trim().isNotEmpty) {
        final r = await api.search(_searchQuery);
        if (mounted) setState(() => _searchResults = r);
      } else if (_category != 'Semua') {
        final r = await api.getCategory(_category);
        if (mounted) setState(() => _searchResults = r);
      }
    } on AuthException {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Segarkan tampilan setelah perubahan data (hapus, extract, rename,
  /// buat folder): daftar aktif (pencarian/filter) atau isi folder.
  Future<void> _refreshAfterMutation() async {
    if (_searchQuery.trim().isNotEmpty || _category != 'Semua') {
      await _refetchActiveList();
    } else {
      await _loadContentOnly();
    }
  }

  Future<void> _doSearch(String q) async {
    _searchQuery = q;
    if (q.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    try {
      final r = await api.search(q);
      if (mounted) setState(() => _searchResults = r);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _doCategory(String cat) async {
    setState(() {
      _category = cat;
      _searchQuery = '';
    });
    if (cat == 'Semua') {
      await _loadContentOnly();
      return;
    }
    try {
      final r = await api.getCategory(cat);
      if (mounted) setState(() => _searchResults = r);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openFolder(TeleFolder f) async {
    _stack.add(f);
    setState(() {
      _folderId = f.id;
      _searchResults = null;
      _searchQuery = '';
      _category = 'Semua';
    });
    await _loadContentOnly();
  }

  Future<void> _goBackFolder() async {
    if (_stack.isEmpty) return;
    _stack.removeLast();
    setState(() {
      _folderId = _stack.isEmpty ? 0 : _stack.last.id;
      _searchResults = null;
      _searchQuery = '';
      _category = 'Semua';
    });
    await _loadContentOnly();
  }

  Future<void> _promptText({
    required String title,
    required String label,
    String initial = '',
    required Future<void> Function(String value) onSave,
  }) async {
    final ctl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true && ctl.text.trim().isNotEmpty) {
      try {
        await onSave(ctl.text.trim());
        await _refreshAfterMutation();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
    ctl.dispose();
  }

  Future<void> _upload() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.single.path == null) return;
    if (!mounted) return;
    final path = picked.files.single.path!;
    final name = picked.files.single.name;
    messenger.showSnackBar(SnackBar(content: Text('Mengupload $name...')));
    try {
      await api.uploadFile(File(path), name, _folderId);
      if (mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text('Upload selesai: $name')));
      }
      await _loadAll();
    } on TelegramDisconnectedException {
      if (mounted) setState(() => _telegramDown = true);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text(
                'Upload gagal: ${e.toString().replaceFirst('Exception: ', '')}')));
      }
    }
  }

  Future<void> _downloadAndShare(TeleFile f) async {
    showInfo(context, 'Mendownload ${f.fileName}...');
    try {
      final dir = await getTemporaryDirectory();
      final downloaded = await api.downloadFile(f, dir);
      if (!mounted) return;
      await Share.shareXFiles([XFile(downloaded.path)],
          text: 'TeleDrive: ${f.fileName}');
    } catch (e) {
      if (mounted) showError(context, e, prefix: 'Download gagal');
    }
  }

  Future<void> _openPreview(TeleFile f) async {
    if (!isPreviewable(f)) {
      await _fileActions(f);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FilePreviewScreen(file: f)),
    );
    // File bisa saja dihapus/diubah dari preview lewat share; segarkan.
    await _refreshAfterMutation();
  }

  Future<void> _fileActions(TeleFile f) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPreviewable(f))
              ListTile(
                leading: const Icon(Icons.visibility_rounded),
                title: const Text('Preview'),
                subtitle: Text('${f.fileName} • ${formatBytes(f.fileSize)}'),
                onTap: () => Navigator.of(ctx).pop('preview'),
              ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download / Bagikan'),
              subtitle: Text('${f.fileName} • ${formatBytes(f.fileSize)}'),
              onTap: () => Navigator.of(ctx).pop('download'),
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Buat link share'),
              onTap: () => Navigator.of(ctx).pop('share'),
            ),
            if (f.isZip)
              ListTile(
                leading: const Icon(Icons.folder_zip_rounded),
                title: const Text('Extract ZIP ke folder ini'),
                onTap: () => Navigator.of(ctx).pop('extract'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Hapus (di Telegram juga)'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      if (choice == 'preview') {
        await _openPreview(f);
      } else if (choice == 'download') {
        await _downloadAndShare(f);
      } else if (choice == 'share') {
        final url = await api.shareFile(f.id);
        if (mounted) await Share.share(url, subject: f.fileName);
      } else if (choice == 'extract') {
        final n = await api.extractZip(f.id, _folderId);
        if (mounted) showInfo(context, 'Extract selesai: $n file.');
        await _refreshAfterMutation();
      } else if (choice == 'delete') {
        final yes = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus file?'),
            content: Text('${f.fileName} akan dihapus dari Telegram dan database.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Batal')),
              FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Hapus')),
            ],
          ),
        );
        if (yes == true) {
          await api.deleteFile(f.id, f.messageId);
          if (mounted) showInfo(context, 'File dihapus: ${f.fileName}');
          await _refreshAfterMutation();
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _syncNow() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await api.syncNow();
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('Sync selesai, $added file baru.')));
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text(
              'Sync gagal: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  int _countFor(String cat) {
    if (_stats == null) return 0;
    final entry = _stats!.categories[cat];
    return entry?['count'] ?? 0;
  }

  Widget _categoryIcon(String category, {double size = 48}) {
    final style = TeleDriveTheme.categoryStyle(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(style.icon, color: style.color, size: size * 0.52),
    );
  }

  Widget _folderRow(TeleFolder f, int index) {
    return FadeSlideIn(
      delay: Duration(milliseconds: 40 * (index % 8)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
        blur: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        radius: 20,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF9AB00).withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.folder_rounded,
                color: Color(0xFFEF8F00), size: 26),
          ),
          title: Text(
            f.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: const Text('Folder'),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) async {
              if (v == 'rename') {
                await _promptText(
                  title: 'Rename folder',
                  label: 'Nama baru',
                  initial: f.name,
                  onSave: (val) => api.renameFolder(f.id, val),
                );
              } else if (v == 'delete') {
                await api.deleteFolder(f.id);
                await _refreshAfterMutation();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
          onTap: () => _openFolder(f),
        ),
      ),
    ),
    );
  }

  Widget _fileRow(TeleFile f, int index) {
    return FadeSlideIn(
      delay: Duration(milliseconds: 40 * (index % 8)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
        blur: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        radius: 20,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: _categoryIcon(f.category),
          title: Text(
            f.fileName,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${formatBytes(f.fileSize)}  •  ${f.uploadTime}  •  ${f.category}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _fileActions(f),
          ),
          onTap: () => _openPreview(f),
        ),
      ),
    ),
    );
  }

  Widget _fileGridTile(TeleFile f, int index) {
    return FadeSlideIn(
      delay: Duration(milliseconds: 40 * (index % 8)),
      child: GlassCard(
      blur: false,
      radius: 22,
      padding: const EdgeInsets.all(14),
      onTap: () => _openPreview(f),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _categoryIcon(f.category, size: 52),
          const SizedBox(height: 12),
          Text(
            f.fileName,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            formatBytes(f.fileSize),
            style: const TextStyle(color: TeleDriveTheme.inkSoft, fontSize: 12),
          ),
          Text(
            f.uploadTime,
            style: const TextStyle(color: TeleDriveTheme.inkSoft, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final files = _searchResults ?? _content?.files ?? const <TeleFile>[];
    final folders = _searchResults == null
        ? (_content?.folders ?? const <TeleFolder>[])
        : const <TeleFolder>[];
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _upload,
          icon: const Icon(Icons.upload_rounded),
          label: const Text('Upload'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              FadeSlideIn(child: _header()),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadAll,
                  color: TeleDriveTheme.teal,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    children: [
                      if (_telegramDown) _telegramBanner(),
                      if (_stats != null)
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 60),
                          child: _statsCard(),
                        ),
                      const SizedBox(height: 14),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: _searchField(),
                      ),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 160),
                        child: _categoryRow(),
                      ),
                      const SizedBox(height: 18),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        GlassCard(
                          blur: false,
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        )
                      else if (folders.isEmpty && files.isEmpty)
                        _emptyState()
                      else ...[
                        if (folders.isNotEmpty) ...[
                          _sectionTitle('Folder', folders.length),
                          ...folders.asMap().entries.map((e) => _folderRow(e.value, e.key)),
                          const SizedBox(height: 8),
                        ],
                        if (files.isNotEmpty) ...[
                          _sectionTitle('File', files.length),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            child: _gridView
                                ? GridView.builder(
                                    key: const ValueKey('grid'),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.86,
                              ),
                              itemCount: files.length,
                              itemBuilder: (_, i) => _fileGridTile(files[i], i),
                            )
                                : Column(
                                    key: const ValueKey('list'),
                                    children: files
                                        .asMap()
                                        .entries
                                        .map((e) => _fileRow(e.value, e.key))
                                        .toList(),
                                  ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          if (_stack.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GlassIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Kembali',
                onPressed: _goBackFolder,
              ),
            ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [TeleDriveTheme.mint, TeleDriveTheme.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: TeleDriveTheme.teal.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.cloud_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TeleDrive',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: TeleDriveTheme.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  _folderName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: TeleDriveTheme.inkSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GlassIconButton(
            icon: Icons.sync_rounded,
            tooltip: 'Sync Telegram',
            onPressed: _syncNow,
          ),
          const SizedBox(width: 6),
          GlassIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'Pengaturan Sync',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SyncSettingsScreen()),
            ),
          ),
          const SizedBox(width: 6),
          GlassIconButton(
            icon: Icons.create_new_folder_rounded,
            tooltip: 'Folder baru',
            onPressed: () => _promptText(
              title: 'Folder baru',
              label: 'Nama folder',
              onSave: (v) => api.createFolder(v, _folderId),
            ),
          ),
          const SizedBox(width: 6),
          GlassIconButton(
            icon: Icons.logout_rounded,
            tooltip: 'Logout',
            onPressed: () async {
              final navigator = Navigator.of(context);
              await api.logout();
              navigator.pushReplacementNamed('/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _telegramBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        blur: false,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Telegram belum terhubung',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Dashboard terkunci sampai login Telegram selesai.',
                    style: TextStyle(color: TeleDriveTheme.inkSoft, fontSize: 13),
                  ),
                ],
              ),
            ),
            TextButton(
              child: const Text('Login'),
              onPressed: () => Navigator.of(context)
                  .pushReplacementNamed('/telegram'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsCard() {
    final s = _stats!;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: TeleDriveTheme.teal.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.storage_rounded,
                    color: TeleDriveTheme.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.totalFiles} file',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: TeleDriveTheme.ink,
                      ),
                    ),
                    Text(
                      formatBytes(s.totalSize),
                      style: const TextStyle(color: TeleDriveTheme.inkSoft),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.cloud_done_rounded,
                  color: TeleDriveTheme.teal, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories
                  .where((c) => c != 'Semua')
                  .map((c) {
                    final style = TeleDriveTheme.categoryStyle(c);
                    final selected = _category == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _doCategory(c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? style.color
                                : style.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(style.icon,
                                  size: 17,
                                  color: selected
                                      ? Colors.white
                                      : style.color),
                              const SizedBox(width: 6),
                              Text(
                                '$c · ${_countFor(c)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : TeleDriveTheme.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Cari di TeleDrive...',
            hintStyle: const TextStyle(color: TeleDriveTheme.inkSoft),
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white.withOpacity(0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide:
                  const BorderSide(color: TeleDriveTheme.teal, width: 1.6),
            ),
          ),
          onChanged: (v) {
            if (v.trim().isEmpty) {
              setState(() {
                _searchResults = null;
                _searchQuery = '';
              });
            }
          },
          onSubmitted: _doSearch,
        ),
      ),
    );
  }

  Widget _categoryRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => _doCategory(c),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _sectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: TeleDriveTheme.ink,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: TeleDriveTheme.teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TeleDriveTheme.tealDark,
              ),
            ),
          ),
          const Spacer(),
          if (title == 'File')
            GlassIconButton(
              icon: _gridView
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              tooltip: _gridView ? 'Tampilan list' : 'Tampilan grid',
              onPressed: () => setState(() => _gridView = !_gridView),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const GlassCard(
      padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 52, color: TeleDriveTheme.teal),
          SizedBox(height: 12),
          Text(
            'Folder ini kosong',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Upload file pertama dengan tombol Upload di bawah.',
            textAlign: TextAlign.center,
            style: TextStyle(color: TeleDriveTheme.inkSoft),
          ),
        ],
      ),
    );
  }
}
