import 'dart:ui';

import 'package:flutter/material.dart';

/// Tema TeleDrive: gaya Google Drive + liquid glass.
///
/// Latar gradien teal lembut, permukaan kaca (blur + putih translusen +
/// border putih + bayangan halus), sudut besar, dan aksen teal yang sama
/// dengan ikon aplikasi. Semua layar memakai latar + kartu dari file ini,
/// jadi tampilannya konsisten. Logika/API tidak berubah.
class TeleDriveTheme {
  static const teal = Color(0xFF0F766E);
  static const tealDark = Color(0xFF115E59);
  static const mint = Color(0xFF14B8A6);
  static const ink = Color(0xFF0F2A28);
  static const inkSoft = Color(0xFF5A6B69);

  static const backgroundTop = Color(0xFFDFF3EF);
  static const backgroundMid = Color(0xFFEFF7F5);
  static const backgroundBottom = Color(0xFFE8F0FE);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: GlassPageTransitionsBuilder(),
          TargetPlatform.iOS: GlassPageTransitionsBuilder(),
          TargetPlatform.macOS: GlassPageTransitionsBuilder(),
          TargetPlatform.windows: GlassPageTransitionsBuilder(),
          TargetPlatform.linux: GlassPageTransitionsBuilder(),
          TargetPlatform.fuchsia: GlassPageTransitionsBuilder(),
        },
      ),
      fontFamily: null,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: ink),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withOpacity(0.65),
        selectedColor: teal,
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(color: ink),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide(color: Colors.white.withOpacity(0.7)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.75),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: teal, width: 1.6),
        ),
        labelStyle: const TextStyle(color: inkSoft),
        prefixIconColor: inkSoft,
        suffixIconColor: inkSoft,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tealDark,
          side: BorderSide(color: teal.withOpacity(0.45)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: tealDark),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: const Color(0xFFF4FAF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFFF2F8F7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFFF4FAF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: teal),
      dividerTheme: DividerThemeData(color: ink.withOpacity(0.08)),
    );
  }

  /// Warna + ikon tiap kategori, gaya Google Drive.
  static CategoryStyle categoryStyle(String category) {
    switch (category) {
      case 'Image':
        return const CategoryStyle(Color(0xFF1A73E8), Icons.image_rounded);
      case 'Video':
        return const CategoryStyle(Color(0xFFD93025), Icons.movie_rounded);
      case 'Audio':
        return const CategoryStyle(Color(0xFFF9AB00), Icons.music_note_rounded);
      case 'Document':
        return const CategoryStyle(Color(0xFF673AB7), Icons.description_rounded);
      case 'Archive':
        return const CategoryStyle(Color(0xFF00897B), Icons.archive_rounded);
      default:
        return const CategoryStyle(Color(0xFF5F6368), Icons.insert_drive_file_rounded);
    }
  }
}

class CategoryStyle {
  final Color color;
  final IconData icon;
  const CategoryStyle(this.color, this.icon);
}

/// Latar gradien + gelembung warna lembut untuk semua layar.
/// Dipakai sebagai dasar Stack; konten ditaruh di atasnya.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TeleDriveTheme.backgroundTop,
            TeleDriveTheme.backgroundMid,
            TeleDriveTheme.backgroundBottom,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -50,
            child: _Blob(
              size: 260,
              color: TeleDriveTheme.mint.withOpacity(0.35),
            ),
          ),
          Positioned(
            top: 190,
            left: -80,
            child: _Blob(
              size: 220,
              color: const Color(0xFF7DD3FC).withOpacity(0.35),
            ),
          ),
          Positioned(
            bottom: -60,
            right: 40,
            child: _Blob(
              size: 200,
              color: const Color(0xFFFDE68A).withOpacity(0.30),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Kartu kaca: blur latar di belakangnya + permukaan putih translusen.
/// [blur] dimatikan untuk baris list yang banyak supaya scroll tetap halus;
/// tampilannya tetap kaca karena permukaannya translusen di atas gradien.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blur;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.blur = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.72),
            Colors.white.withOpacity(0.42),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.75)),
        boxShadow: [
          BoxShadow(
            color: TeleDriveTheme.tealDark.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: card,
            )
          : card,
    );
    if (onTap == null) return clipped;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: clipped,
      ),
    );
  }
}

/// Transisi antar-halaman untuk semua route: fade + geser naik halus,
/// gaya liquid glass (dipakai ThemeData.pageTransitionsTheme).
class GlassPageTransitionsBuilder extends PageTransitionsBuilder {
  const GlassPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Animasi masuk: fade + geser naik, dengan jeda untuk efek stagger
/// (dipakai header, kartu statistik, dan baris file/folder).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _offset =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
            .animate(curved);
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// Tombol ikon kaca kecil (toolbar atas, gaya liquid glass).
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.65),
              border: Border.all(color: Colors.white.withOpacity(0.8)),
              boxShadow: [
                BoxShadow(
                  color: TeleDriveTheme.tealDark.withOpacity(0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 21, color: TeleDriveTheme.ink),
          ),
        ),
      ),
    );
  }
}
