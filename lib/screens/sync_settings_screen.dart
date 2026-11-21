import 'package:flutter/material.dart';

import '../api/teledrive_api.dart';
import '../main.dart';
import '../models.dart';

/// Pengaturan sync: manual / auto / off + interval.
/// Mengikuti /api/sync-settings di backend (tersimpan di DB, selamat restart).
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});
  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  SyncSettings? _settings;
  String _mode = 'manual';
  int _interval = 15;
  bool _loading = true;
  bool _saving = false;

  static const intervals = [1, 5, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await api.getSyncSettings();
      if (mounted) {
        setState(() {
          _settings = s;
          _mode = s.mode;
          _interval = s.intervalMinutes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showError(context, e);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final s = await api.setSyncSettings(_mode, _interval);
      if (mounted) {
        setState(() => _settings = s);
        showInfo(context, 'Pengaturan sync disimpan.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Sync')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Mode off juga memblokir tombol Sync manual. Mode auto jalan di server tiap interval selama Telegram terhubung.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _mode,
                    decoration: const InputDecoration(
                        labelText: 'Mode', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'manual', child: Text('Manual')),
                      DropdownMenuItem(value: 'auto', child: Text('Otomatis')),
                      DropdownMenuItem(value: 'off', child: Text('Mati (off)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _mode = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _interval,
                    decoration: const InputDecoration(
                        labelText: 'Interval auto-sync (menit)',
                        border: OutlineInputBorder()),
                    items: intervals
                        .map((i) => DropdownMenuItem(
                            value: i, child: Text('$i menit')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _interval = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_settings != null)
                    Text(
                      'Terakhir sync: ${_settings!.lastSyncAt.isEmpty ? '-' : _settings!.lastSyncAt} '
                      '(${_settings!.lastSyncAdded} file baru) • '
                      'Telegram: ${_settings!.telegramConnected ? 'terhubung' : 'putus'}',
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Simpan'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _mode == 'off'
                        ? null
                        : () async {
                            try {
                              final added = await api.syncNow();
                              if (context.mounted) {
                                showInfo(context,
                                    'Sync selesai, $added file baru.');
                              }
                              await _load();
                            } catch (e) {
                              if (context.mounted) showError(context, e);
                            }
                          },
                    child: const Text('Sync Sekarang'),
                  ),
                ],
              ),
            ),
    );
  }
}
