import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeBackButton extends StatefulWidget {
  const HomeBackButton({super.key});

  @override
  State<HomeBackButton> createState() => _HomeBackButtonState();
}

class _HomeBackButtonState extends State<HomeBackButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (!_hovered) {
          setState(() => _hovered = true);
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
