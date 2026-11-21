// Model untuk TeleDrive — bentuknya mengikuti JSON dari backend FastAPI
// di /root/teledrive-backend/main.py (tabel folders / files, drive.db).

class TeleFolder {
  final int id;
  final String name;
  final int parentId;
  TeleFolder({required this.id, required this.name, this.parentId = 0});
  factory TeleFolder.fromJson(Map<String, dynamic> j) => TeleFolder(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        parentId: (j['parent_id'] as num?)?.toInt() ?? 0,
      );
}

class TeleFile {
  final int id;
  final String fileName;
  final int messageId;
  final int fileSize;
  final String uploadTime;
  final int folderId;
  final String category;
  final String? shareToken;
  TeleFile({
    required this.id,
    required this.fileName,
    required this.messageId,
    required this.fileSize,
    required this.uploadTime,
    required this.folderId,
    required this.category,
    this.shareToken,
  });
  factory TeleFile.fromJson(Map<String, dynamic> j) => TeleFile(
        id: (j['id'] as num?)?.toInt() ?? 0,
        fileName: (j['file_name'] ?? '').toString(),
        messageId: (j['message_id'] as num?)?.toInt() ?? 0,
        fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
        uploadTime: (j['upload_time'] ?? '').toString(),
        folderId: (j['folder_id'] as num?)?.toInt() ?? 0,
        category: (j['category'] ?? 'Other').toString(),
        shareToken: j['share_token']?.toString(),
      );
  bool get isZip => fileName.toLowerCase().endsWith('.zip');
}

class FolderContent {
  final List<TeleFolder> folders;
  final List<TeleFile> files;
  FolderContent({required this.folders, required this.files});
  factory FolderContent.fromJson(Map<String, dynamic> j) => FolderContent(
        folders: ((j['folders'] as List?) ?? [])
            .map((e) => TeleFolder.fromJson(e as Map<String, dynamic>))
            .toList(),
        files: ((j['files'] as List?) ?? [])
            .map((e) => TeleFile.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TelegramStatus {
  final bool connected;
  final String status;
  final String detail;
  final Map<String, dynamic>? account;
  final bool pending;
  final bool needsPassword;
  final String phoneMasked;
  TelegramStatus({
    required this.connected,
    required this.status,
    required this.detail,
    this.account,
    required this.pending,
    required this.needsPassword,
    required this.phoneMasked,
  });
  factory TelegramStatus.fromJson(Map<String, dynamic> j) => TelegramStatus(
        connected: j['connected'] == true,
        status: (j['status'] ?? '').toString(),
        detail: (j['detail'] ?? '').toString(),
        account: j['account'] as Map<String, dynamic>?,
        pending: j['pending'] == true,
        needsPassword: j['needs_password'] == true,
        phoneMasked: (j['phone_masked'] ?? '').toString(),
      );
}

class DashboardStats {
  final int totalFiles;
  final int totalSize;
  final Map<String, Map<String, int>> categories;
  final List<String> chartLabels;
  final List<int> chartValues;
  DashboardStats({
    required this.totalFiles,
    required this.totalSize,
    required this.categories,
    required this.chartLabels,
    required this.chartValues,
  });
  factory DashboardStats.fromJson(Map<String, dynamic> j) {
    final cats = <String, Map<String, int>>{};
    final raw = j['categories'] as Map<String, dynamic>?;
    raw?.forEach((k, v) {
      final m = v as Map<String, dynamic>;
      cats[k] = {
        'count': (m['count'] as num?)?.toInt() ?? 0,
        'size': (m['size'] as num?)?.toInt() ?? 0,
      };
    });
    return DashboardStats(
      totalFiles: (j['total_files'] as num?)?.toInt() ?? 0,
      totalSize: (j['total_size'] as num?)?.toInt() ?? 0,
      categories: cats,
      chartLabels:
          ((j['chart_labels'] as List?) ?? []).map((e) => e.toString()).toList(),
      chartValues: ((j['chart_values'] as List?) ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

class SyncSettings {
  final String mode; // manual | auto | off
  final int intervalMinutes;
  final String lastSyncAt;
  final int lastSyncAdded;
  final bool telegramConnected;
  SyncSettings({
    required this.mode,
    required this.intervalMinutes,
    required this.lastSyncAt,
    required this.lastSyncAdded,
    required this.telegramConnected,
  });
  factory SyncSettings.fromJson(Map<String, dynamic> j) => SyncSettings(
        mode: (j['mode'] ?? 'manual').toString(),
        intervalMinutes: (j['interval_minutes'] as num?)?.toInt() ?? 15,
        lastSyncAt: (j['last_sync_at'] ?? '').toString(),
        lastSyncAdded: (j['last_sync_added'] as num?)?.toInt() ?? 0,
        telegramConnected: j['telegram_connected'] == true,
      );
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${units[i]}';
}
