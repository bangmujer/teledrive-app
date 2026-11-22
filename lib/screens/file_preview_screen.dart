import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';

enum PreviewKind { image, video, audio, pdf, text, unsupported }

/// Tipe preview dari ekstensi file. Dipakai home screen untuk memutuskan
/// apakah ketukan pada file membuka preview atau langsung menu aksi.
PreviewKind previewKindFor(TeleFile f) {
  final name = f.fileName.toLowerCase();
  final ext = name.contains('.') ? name.split('.').last : '';
  switch (ext) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
    case 'bmp':
      return PreviewKind.image;
    case 'mp4':
    case 'mov':
    case 'm4v':
    case 'webm':
      return PreviewKind.video;
    case 'mp3':
    case 'wav':
    case 'm4a':
    case 'aac':
    case 'ogg':
    case 'opus':
    case 'flac':
      return PreviewKind.audio;
    case 'pdf':
      return PreviewKind.pdf;
    case 'txt':
    case 'md':
    case 'csv':
    case 'json':
    case 'log':
    case 'xml':
    case 'html':
    case 'css':
    case 'js':
    case 'py':
    case 'sh':
    case 'yaml':
    case 'yml':
    case 'ini':
    case 'cfg':
      return PreviewKind.text;
    default:
      return PreviewKind.unsupported;
  }
}

bool isPreviewable(TeleFile f) =>
    previewKindFor(f) != PreviewKind.unsupported;

/// Preview file di dalam app: gambar, video, musik, PDF, dan dokumen teks.
/// File didownload dulu ke folder temporer lewat API yang sama dengan
/// download biasa (cookie sesi ikut terkirim), lalu ditampilkan dari file
/// lokal — tidak ada pemutar/streaming eksternal.
class FilePreviewScreen extends StatefulWidget {
  final TeleFile file;
  const FilePreviewScreen({super.key, required this.file});

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  File? _localFile;
  String? _error;
  String? _textContent;

  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _audioReady = false;

  int _pdfPage = 0;
  int _pdfTotal = 0;

  PreviewKind get _kind => previewKindFor(widget.file);

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final dir = await getTemporaryDirectory();
      final downloaded = await api.downloadFile(widget.file, dir);
      if (!mounted) return;
      setState(() => _localFile = downloaded);
      await _prepare(downloaded);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _prepare(File downloaded) async {
    try {
      switch (_kind) {
        case PreviewKind.video:
          final c = VideoPlayerController.file(downloaded);
          await c.initialize();
          _videoController = c;
          if (mounted) setState(() {});
          break;
        case PreviewKind.audio:
          final p = AudioPlayer();
          await p.setFilePath(downloaded.path);
          _audioPlayer = p;
          if (mounted) setState(() => _audioReady = true);
          break;
        case PreviewKind.text:
          final bytes = await downloaded.readAsBytes();
          final text = utf8.decode(bytes, allowMalformed: true);
          if (mounted) {
            setState(() => _textContent =
                text.length > 300000 ? '${text.substring(0, 300000)}\n…' : text);
          }
          break;
        default:
          break;
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final f = _localFile;
    if (f == null) return;
    await Share.shareXFiles([XFile(f.path)], text: 'TeleDrive: ${widget.file.fileName}');
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            f.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_localFile != null)
              GlassIconButton(
                icon: Icons.share_rounded,
                tooltip: 'Bagikan',
                onPressed: _share,
              ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: Colors.red),
                const SizedBox(height: 12),
                const Text('Preview gagal dibuka',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _localFile = null;
                    });
                    _download();
                  },
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final local = _localFile;
    if (local == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Mendownload file untuk preview...',
                style: TextStyle(color: TeleDriveTheme.inkSoft)),
          ],
        ),
      );
    }
    switch (_kind) {
      case PreviewKind.image:
        return InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image.file(
              local,
              fit: BoxFit.contain,
              frameBuilder: (ctx, child, frame, _) => AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: child,
              ),
            ),
          ),
        );
      case PreviewKind.video:
        return _videoView();
      case PreviewKind.audio:
        return _audioView();
      case PreviewKind.pdf:
        return _pdfView(local);
      case PreviewKind.text:
        return _textView();
      case PreviewKind.unsupported:
        return _unsupportedView();
    }
  }

  Widget _videoView() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: VideoPlayer(c),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (_, v, __) {
              final pos = v.position;
              final dur = v.duration;
              final max = dur.inMilliseconds.toDouble();
              return Column(
                children: [
                  Slider(
                    value: max > 0
                        ? pos.inMilliseconds.toDouble().clamp(0, max)
                        : 0,
                    max: max > 0 ? max : 1,
                    activeColor: TeleDriveTheme.teal,
                    onChanged: (val) =>
                        c.seekTo(Duration(milliseconds: val.toInt())),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(v.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded),
                        iconSize: 44,
                        color: TeleDriveTheme.teal,
                        onPressed: () =>
                            v.isPlaying ? c.pause() : c.play(),
                      ),
                      Text('${_fmt(pos)} / ${_fmt(dur)}',
                          style: const TextStyle(
                              color: TeleDriveTheme.inkSoft)),
                      const Spacer(),
                      Text(
                        widget.file.fileName,
                        style: const TextStyle(
                            color: TeleDriveTheme.inkSoft, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _audioView() {
    final p = _audioPlayer;
    final style = TeleDriveTheme.categoryStyle(widget.file.category);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [style.color.withOpacity(0.85), TeleDriveTheme.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: style.color.withOpacity(0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(Icons.music_note_rounded,
                size: 76, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            widget.file.fileName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '${formatBytes(widget.file.fileSize)}  •  ${widget.file.uploadTime}',
            style: const TextStyle(color: TeleDriveTheme.inkSoft),
          ),
          const SizedBox(height: 28),
          if (p == null || !_audioReady)
            const CircularProgressIndicator()
          else
            StreamBuilder<Duration>(
              stream: p.positionStream,
              builder: (_, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                return StreamBuilder<Duration?>(
                  stream: p.durationStream,
                  builder: (_, durSnap) {
                    final dur = durSnap.data ?? Duration.zero;
                    final max = dur.inMilliseconds.toDouble();
                    return Column(
                      children: [
                        Slider(
                          value: max > 0
                              ? pos.inMilliseconds.toDouble().clamp(0, max)
                              : 0,
                          max: max > 0 ? max : 1,
                          activeColor: TeleDriveTheme.teal,
                          onChanged: (val) => p
                              .seek(Duration(milliseconds: val.toInt())),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(pos),
                                style: const TextStyle(
                                    color: TeleDriveTheme.inkSoft)),
                            Text(_fmt(dur),
                                style: const TextStyle(
                                    color: TeleDriveTheme.inkSoft)),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 10),
          if (p != null && _audioReady)
            StreamBuilder<PlayerState>(
              stream: p.playerStateStream,
              builder: (_, snap) {
                final playing = snap.data?.playing ?? false;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10_rounded),
                      iconSize: 34,
                      color: TeleDriveTheme.tealDark,
                      onPressed: () {
                        p.seek(p.position - const Duration(seconds: 10));
                      },
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: TeleDriveTheme.teal,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white),
                        iconSize: 34,
                        onPressed: () => playing ? p.pause() : p.play(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.forward_10_rounded),
                      iconSize: 34,
                      color: TeleDriveTheme.tealDark,
                      onPressed: () {
                        p.seek(p.position + const Duration(seconds: 10));
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _pdfView(File local) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PDFView(
              filePath: local.path,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: false,
              pageFling: true,
              onPageChanged: (page, total) {
                if (mounted) {
                  setState(() {
                    _pdfPage = page ?? 0;
                    _pdfTotal = total ?? 0;
                  });
                }
              },
              onError: (e) {
                if (mounted) setState(() => _error = e.toString());
              },
            ),
          ),
        ),
        if (_pdfTotal > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Halaman ${_pdfPage + 1} dari $_pdfTotal',
              style: const TextStyle(color: TeleDriveTheme.inkSoft),
            ),
          ),
      ],
    );
  }

  Widget _textView() {
    final text = _textContent;
    if (text == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GlassCard(
        blur: false,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _unsupportedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _categoryIconLarge(),
              const SizedBox(height: 14),
              Text(
                widget.file.fileName,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Preview belum tersedia untuk tipe file ini di dalam app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: TeleDriveTheme.inkSoft),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download / Bagikan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryIconLarge() {
    final style = TeleDriveTheme.categoryStyle(widget.file.category);
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: style.color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Icon(style.icon, color: style.color, size: 44),
    );
  }
}
