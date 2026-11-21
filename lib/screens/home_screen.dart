import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/teledrive_api.dart';
import '../main.dart';
import '../models.dart';
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
  String _category = 'Semua';
  bool _loading = false;
  bool _telegramDown = false;
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

  Future<void> _doSearch(String q) async {
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
    setState(() => _category = cat);
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
        await _loadContentOnly();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
    ctl.dispose();
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.single.path == null) return;
    final path = picked.files.single.path!;
    final name = picked.files.single.name;
    showInfo(context, 'Mengupload $name...');
    try {
      await api.uploadFile(File(path), name, _folderId);
      if (mounted) showInfo(context, 'Upload selesai: $name');
      await _loadAll();
    } on TelegramDisconnectedException {
      if (mounted) setState(() => _telegramDown = true);
    } catch (e) {
      if (mounted) showError(context, e, prefix: 'Upload gagal');
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

  Future<void> _fileActions(TeleFile f) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download / Bagikan'),
              subtitle: Text('${f.fileName} • ${formatBytes(f.fileSize)}'),
              onTap: () => Navigator.of(ctx).pop('download'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Buat link share'),
              onTap: () => Navigator.of(ctx).pop('share'),
            ),
            if (f.isZip)
              ListTile(
                leading: const Icon(Icons.folder_zip),
                title: const Text('Extract ZIP ke folder ini'),
                onTap: () => Navigator.of(ctx).pop('extract'),
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Hapus (di Telegram juga)'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      if (choice == 'download') {
        await _downloadAndShare(f);
      } else if (choice == 'share') {
        final url = await api.shareFile(f.id);
        if (mounted) await Share.share(url, subject: f.fileName);
      } else if (choice == 'extract') {
        final n = await api.extractZip(f.id, _folderId);
        if (mounted) showInfo(context, 'Extract selesai: $n file.');
        await _loadContentOnly();
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
          await _loadContentOnly();
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'Image':
        return Icons.image;
      case 'Video':
        return Icons.movie;
      case 'Audio':
        return Icons.music_note;
      case 'Archive':
        return Icons.archive;
      case 'Document':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = _searchResults ?? _content?.files ?? const <TeleFile>[];
    final folders = _searchResults == null ? (_content?.folders ?? const <TeleFolder>[]) : const <TeleFolder>[];
    return Scaffold(
      appBar: AppBar(
        title: Text('TeleDrive — $_folderName'),
        leading: _stack.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBackFolder),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Telegram',
            onPressed: () async {
              try {
                final added = await api.syncNow();
                if (mounted) showInfo(context, 'Sync selesai, $added file baru.');
                await _loadAll();
              } catch (e) {
                if (mounted) showError(context, e, prefix: 'Sync gagal');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Pengaturan Sync',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SyncSettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Folder baru',
            onPressed: () => _promptText(
              title: 'Folder baru',
              label: 'Nama folder',
              onSave: (v) => api.createFolder(v, _folderId),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await api.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        icon: const Icon(Icons.upload),
        label: const Text('Upload'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_telegramDown)
              Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.orange),
                  title: const Text('Telegram belum terhubung'),
                  subtitle: const Text('Dashboard terkunci sampai login Telegram selesai.'),
                  trailing: TextButton(
                    child: const Text('Login Telegram'),
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed('/telegram'),
                  ),
                ),
              ),
            if (_stats != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storage),
                  title: Text(
                      '${_stats!.totalFiles} file • ${formatBytes(_stats!.totalSize)}'),
                  subtitle: Text(_stats!.categories.entries
                      .map((e) => '${e.key}: ${e.value['count']}')
                      .join('  •  ')),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Cari file...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                if (v.trim().isEmpty) {
                  setState(() => _searchResults = null);
                }
              },
              onSubmitted: _doSearch,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
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
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (folders.isEmpty && files.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Kosong. Upload file pertama.')),
              ),
            ...folders.map((f) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder, color: Colors.amber),
                    title: Text(f.name),
                    trailing: PopupMenuButton<String>(
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
                          await _loadContentOnly();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                    onTap: () => _openFolder(f),
                  ),
                )),
            ...files.map((f) => Card(
                  child: ListTile(
                    leading: Icon(_iconFor(f.category)),
                    title: Text(f.fileName),
                    subtitle: Text(
                        '${formatBytes(f.fileSize)} • ${f.uploadTime} • ${f.category}'),
                    trailing: const Icon(Icons.more_vert),
                    onTap: () => _fileActions(f),
                  ),
                )),
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }
}
