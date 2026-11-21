// API client untuk backend TeleDrive (FastAPI).
//
// PENTING — auth backend ini BUKAN token JSON:
//  * POST /login (form) -> cookie `session_token` (httponly, 30 hari).
//    Cookie itu nilainya sama dengan API_HASH server, jadi JANGAN pernah
//    di-log / ditampilkan. Client ini hanya menyimpannya di
//    SharedPreferences dan mengirimkannya kembali sebagai header Cookie.
//  * Semua endpoint dashboard mewajibkan cookie itu (check_auth) DAN
//    Telegram terhubung (_require_tg) — kalau Telegram putus, server
//    menjawab 503. Kecuali /api/sync-settings dan /api/telegram/status
//    yang sengaja tidak di-gate Telegram.
//  * Endpoint login Telegram (/api/telegram/request-code & verify-code)
//    menjawab Redirect 303 ke /telegram-login; kalau ada `error=` di
//    Location-nya, itu pesan error yang harus ditampilkan.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class TelegramDisconnectedException implements Exception {
  final String message;
  TelegramDisconnectedException(
      [this.message = 'Telegram belum terhubung. Login ulang lewat menu Telegram.']);
  @override
  String toString() => message;
}

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class TeleDriveApi {
  static const String defaultBaseUrl = 'https://teledrive.mjr-dev.my.id';
  static const String _kBaseUrl = 'teledrive_base_url';
  static const String _kCookie = 'teledrive_session_cookie';

  String _baseUrl = defaultBaseUrl;
  String? _cookie;
  SharedPreferences? _prefs;

  String get baseUrl => _baseUrl;
  bool get hasSession => _cookie != null && _cookie!.isNotEmpty;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _baseUrl = _prefs!.getString(_kBaseUrl) ?? defaultBaseUrl;
    _cookie = _prefs!.getString(_kCookie);
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _prefs?.setString(_kBaseUrl, _baseUrl);
  }

  Future<void> clearSession() async {
    _cookie = null;
    await _prefs?.remove(_kCookie);
  }

  Map<String, String> _headers({bool json = false}) {
    final h = <String, String>{};
    if (_cookie != null && _cookie!.isNotEmpty) h['Cookie'] = _cookie!;
    if (json) h['Content-Type'] = 'application/json';
    return h;
  }

  String _extractCookie(http.Response res) {
    // http package menormalisasi nama header jadi lowercase.
    final raw = res.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return '';
    // Ambil pasangan pertama: session_token=...
    final first = raw.split(',').firstWhere(
          (p) => p.trim().startsWith('session_token='),
          orElse: () => raw.split(';').first,
        );
    return first.split(';').first.trim();
  }

  Never _throwForStatus(http.Response res) {
    if (res.statusCode == 401) {
      throw AuthException('Sesi habis. Login ulang.');
    }
    if (res.statusCode == 503) {
      throw TelegramDisconnectedException(_detailFromBody(res.body));
    }
    throw ApiException(res.statusCode, _detailFromBody(res.body));
  }

  String _detailFromBody(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['detail'] != null) return j['detail'].toString();
    } catch (_) {}
    final t = body.trim();
    return t.isEmpty ? 'Request gagal.' : t;
  }

  dynamic _decodeJson(http.Response res) {
    if (res.statusCode == 401) throw AuthException('Sesi habis. Login ulang.');
    if (res.statusCode == 503) {
      throw TelegramDisconnectedException(_detailFromBody(res.body));
    }
    if (res.statusCode < 200 || res.statusCode >= 300) _throwForStatus(res);
    if (res.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(res.body);
  }

  // ---------- Auth web ----------

  Future<void> login(String username, String password) async {
    final uri = Uri.parse('$_baseUrl/login');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    ).timeout(const Duration(seconds: 30));
    // Sukses = redirect 303 + Set-Cookie. Gagal = 200 (template login.html).
    final cookie = _extractCookie(res);
    if (cookie.isNotEmpty) {
      _cookie = cookie;
      await _prefs?.setString(_kCookie, cookie);
      return;
    }
    if (res.statusCode == 303 || res.statusCode == 302) {
      throw AuthException('Login gagal: cookie tidak diterima.');
    }
    throw AuthException('Username atau password salah.');
  }

  Future<void> logout() async {
    try {
      await http.get(Uri.parse('$_baseUrl/logout'), headers: _headers());
    } catch (_) {}
    await clearSession();
  }

  // ---------- Telegram login ----------

  Future<TelegramStatus> telegramStatus() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/telegram/status'), headers: _headers())
        .timeout(const Duration(seconds: 30));
    final j = _decodeJson(res) as Map<String, dynamic>;
    return TelegramStatus.fromJson(j);
  }

  /// Mengirim kode OTP. Endpoint menjawab 303; error ada di query Location.
  Future<void> requestCode(String phone) async {
    final req = http.Request('POST', Uri.parse('$_baseUrl/api/telegram/request-code'))
      ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
      ..headers.addAll(_headers())
      ..bodyFields = {'phone_number': phone}
      ..followRedirects = false;
    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    final loc = res.headers['location'] ?? '';
    final err = _errorFromLocation(loc);
    if (err != null) throw ApiException(res.statusCode, err);
    if (res.statusCode >= 400) _throwForStatus(res);
  }

  Future<void> verifyCode({required String code, String password = ''}) async {
    final req = http.Request('POST', Uri.parse('$_baseUrl/api/telegram/verify-code'))
      ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
      ..headers.addAll(_headers())
      ..bodyFields = {'phone_code': code, 'password': password}
      ..followRedirects = false;
    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    final err = _errorFromLocation(res.headers['location'] ?? '');
    if (err != null) throw ApiException(res.statusCode, err);
  }

  Future<void> cancelTelegramLogin() async {
    await http
        .post(Uri.parse('$_baseUrl/api/telegram/cancel'), headers: _headers())
        .timeout(const Duration(seconds: 30));
  }

  String? _errorFromLocation(String location) {
    if (location.isEmpty || !location.contains('error=')) return null;
    final uri = Uri.parse(location.startsWith('http') ? location : '$_baseUrl$location');
    final e = uri.queryParameters['error'];
    if (e == null || e.isEmpty) return null;
    return Uri.decodeComponent(e.replaceAll('+', ' '));
  }

  // ---------- Konten ----------

  Future<FolderContent> getContent(int folderId) async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/content/$folderId'), headers: _headers())
        .timeout(const Duration(seconds: 30));
    final j = _decodeJson(res) as Map<String, dynamic>;
    return FolderContent.fromJson(j);
  }

  Future<List<TeleFolder>> getAllFolders() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/all_folders'), headers: _headers())
        .timeout(const Duration(seconds: 30));
    final j = _decodeJson(res) as List;
    return j.map((e) => TeleFolder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TeleFile>> search(String q) async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/search?q=${Uri.encodeQueryComponent(q)}'),
            headers: _headers())
        .timeout(const Duration(seconds: 30));
    final j = _decodeJson(res) as List;
    return j.map((e) => TeleFile.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TeleFile>> getCategory(String cat) async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/category/$cat'), headers: _headers())
        .timeout(const Duration(seconds: 30));
    final j = _decodeJson(res) as List;
    return j.map((e) => TeleFile.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DashboardStats> getDashboard() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/dashboard'), headers: _headers())
        .timeout(const Duration(seconds: 30));
    final j = _decodeJson(res) as Map<String, dynamic>;
    return DashboardStats.fromJson(j);
  }

  Future<void> createFolder(String name, int parentId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/folders'),
      headers: _headers(),
      body: {'name': name, 'parent_id': '$parentId'},
    ).timeout(const Duration(seconds: 30));
    _decodeJson(res);
  }

  Future<void> renameFolder(int folderId, String name) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/folders/$folderId'),
      headers: _headers(),
      body: {'name': name},
    ).timeout(const Duration(seconds: 30));
    _decodeJson(res);
  }

  Future<void> deleteFolder(int folderId) async {
    final res = await http
        .delete(Uri.parse('$_baseUrl/api/folders/$folderId'), headers: _headers())
        .timeout(const Duration(seconds: 30));
    _decodeJson(res);
  }

  Future<void> deleteFile(int dbId, int messageId) async {
    final res = await http
        .delete(Uri.parse('$_baseUrl/api/files/$dbId/$messageId'),
            headers: _headers())
        .timeout(const Duration(seconds: 30));
    _decodeJson(res);
  }

  Future<String> shareFile(int dbId) async {
    final res = await http
        .post(Uri.parse('$_baseUrl/api/share/$dbId'), headers: _headers())
        .timeout(const Duration(seconds: 30));
    final j = _decodeJson(res) as Map<String, dynamic>;
    final token = (j['token'] ?? '').toString();
    if (token.isEmpty) throw ApiException(res.statusCode, 'Token share kosong.');
    return '$_baseUrl/shared/$token';
  }

  Future<int> extractZip(int dbId, int folderId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/extract/$dbId'),
      headers: _headers(),
      body: {'folder_id': '$folderId'},
    ).timeout(const Duration(seconds: 120));
    final j = _decodeJson(res) as Map<String, dynamic>;
    return (j['extracted'] as num?)?.toInt() ?? 0;
  }

  // ---------- Sync ----------

  Future<SyncSettings> getSyncSettings() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/sync-settings'), headers: _headers())
        .timeout(const Duration(seconds: 30));
    final j = _decodeJson(res) as Map<String, dynamic>;
    return SyncSettings.fromJson(j);
  }

  Future<SyncSettings> setSyncSettings(String mode, int intervalMinutes) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/sync-settings'),
      headers: _headers(),
      body: {'mode': mode, 'interval_minutes': '$intervalMinutes'},
    ).timeout(const Duration(seconds: 30));
    final j = _decodeJson(res) as Map<String, dynamic>;
    return SyncSettings.fromJson(j);
  }

  Future<int> syncNow() async {
    final res = await http
        .post(Uri.parse('$_baseUrl/api/sync'), headers: _headers())
        .timeout(const Duration(seconds: 120));
    final j = _decodeJson(res) as Map<String, dynamic>;
    return (j['added'] as num?)?.toInt() ?? 0;
  }

  // ---------- Upload / download ----------

  Future<void> uploadFile(File file, String fileName, int folderId,
      {void Function(int sent, int total)? onProgress}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/upload'));
    req.headers.addAll(_headers());
    req.fields['folder_id'] = '$folderId';
    req.files.add(await http.MultipartFile.fromPath('file', file.path,
        filename: fileName));
    final streamed = await req.send().timeout(const Duration(minutes: 10));
    final res = await http.Response.fromStream(streamed);
    _decodeJson(res);
  }

  Future<void> createTextFile(
      String filename, String content, int folderId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/create_file'),
      headers: _headers(),
      body: {'filename': filename, 'content': content, 'folder_id': '$folderId'},
    ).timeout(const Duration(seconds: 60));
    _decodeJson(res);
  }

  /// Download file ke [dir]/[fileName]. Mengembalikan File hasil download.
  Future<File> downloadFile(TeleFile file, Directory dir) async {
    final safeName = file.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final out = File('${dir.path}/$safeName');
    final req = http.Request('GET', Uri.parse('$_baseUrl/download/${file.id}'));
    req.headers.addAll(_headers());
    final client = http.Client();
    try {
      final streamed = await client.send(req).timeout(const Duration(minutes: 10));
      if (streamed.statusCode == 401) {
        throw AuthException('Sesi habis. Login ulang.');
      }
      if (streamed.statusCode == 503) {
        throw TelegramDisconnectedException();
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw ApiException(streamed.statusCode, 'Download gagal.');
      }
      final sink = out.openWrite();
      await streamed.stream.pipe(sink);
      await sink.close();
      return out;
    } finally {
      client.close();
    }
  }
}
