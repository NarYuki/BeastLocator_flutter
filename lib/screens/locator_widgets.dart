import 'package:flutter/material.dart';

import '../models/destination.dart';
import '../theme/beast_palette.dart';

class LocatorView extends StatelessWidget {
  const LocatorView({
    super.key,
    required this.rotation,
    required this.distanceText,
    required this.directionText,
  });

  final Animation<double> rotation;
  final String distanceText;
  final String directionText;

  @override
  Widget build(BuildContext context) {
    final colors = BeastPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: rotation,
            child: Image.asset(
              'assets/images/yjsnpi.png',
              width: 208,
              height: 208,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
          FittedBox(
            child: Text(
              distanceText,
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
              ).copyWith(color: colors.onSurface),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            directionText,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class ArrivalView extends StatelessWidget {
  const ArrivalView({
    super.key,
    required this.destination,
    required this.name,
    required this.onReset,
  });

  final Destination destination;
  final String? name;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = BeastPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'こ↑こ↓',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name?.isNotEmpty == true ? name! : '正解位置を確認中...',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '緯度 ${destination.lat.toStringAsFixed(6)} / 経度 ${destination.lng.toStringAsFixed(6)}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: FilledButton(
              onPressed: onReset,
              child: const Text('到達状態をリセットする'),
            ),
          ),
        ],
      ),
    );
  }
}

class MainIconButton extends StatelessWidget {
  const MainIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final colors = BeastPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surfaceCard,
        shape: CircleBorder(side: BorderSide(color: colors.outline)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: IconTheme(
              data: IconThemeData(color: colors.onSurface, size: 28),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
