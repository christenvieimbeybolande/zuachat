import 'package:flutter/material.dart';
import 'zua_loader.dart';

/// 🔥 Mini Loader Rouge (vraiment petit + rapide)
class ZuaLoaderMini extends StatelessWidget {
  final double size;
  const ZuaLoaderMini({super.key, this.size = 22}); // taille mini réelle

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ZuaLoader(
        looping: true,
        size: size, // 🔥 respecte la taille voulue
      ),
    );
  }
}
