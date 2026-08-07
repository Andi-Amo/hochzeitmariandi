import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/js_interop.dart';

class HomeBackButton extends StatefulWidget {
  const HomeBackButton({super.key});

  @override
  State<HomeBackButton> createState() => _HomeBackButtonState();
}

class _HomeBackButtonState extends State<HomeBackButton> {
  bool _hovered = false;

  void _playMusic() {
    try {
      callJsMethod('playAudio', []);
    } catch (e) {
      print('Audio playback error: $e');
    }
  }

  void _stopMusic() {
    try {
      callJsMethod('stopAudio', []);
    } catch (e) {
      print('Audio stop error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (!_hovered) {
          setState(() => _hovered = true);
          _playMusic();
        }
      },
      onExit: (_) => setState(() => _hovered = false),
      child: IconButton(
        icon: Icon(_hovered ? Icons.home : Icons.home_outlined),
        onPressed: () {
          _stopMusic();
          context.go('/');
        },
      ),
    );
  }
}
