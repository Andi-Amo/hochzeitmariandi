import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';

class HomeBackButton extends StatefulWidget {
  const HomeBackButton({super.key});

  @override
  State<HomeBackButton> createState() => _HomeBackButtonState();
}

class _HomeBackButtonState extends State<HomeBackButton> {
  bool _hovered = false;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playMusic() async {
    await _audioPlayer.play(AssetSource('assets/audio/take_me_home.webm'));
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
        onPressed: () => context.go('/'),
      ),
    );
  }
}
