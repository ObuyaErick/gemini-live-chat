import 'package:flutter/material.dart';
import 'package:webs/ui/core/app_theme.dart';

/// The agent avatar. Renders, in priority order: the agent's [imageUrl] (e.g.
/// `agent_image_url`), a short text [label] (e.g. the name initial), or an
/// [icon]. A failed/absent image falls back to the label, then the icon, over
/// the brand gradient — so a broken URL or a CORS-blocked image never leaves a
/// blank circle.
class Avatar extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String? imageUrl;
  final Color? bg;
  final Color? fg;
  final double size;

  const Avatar({
    super.key,
    this.icon,
    this.label,
    this.imageUrl,
    this.bg,
    this.fg,
    this.size = 30,
  }) : assert(
         icon != null || label != null || imageUrl != null,
         'Avatar needs an icon, label, or imageUrl',
       );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final useGradient = bg == null;
    final radius = BorderRadius.circular(size / 2);

    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: useGradient ? null : bg,
        gradient: useGradient ? t.accentGradient : null,
        borderRadius: radius,
        boxShadow: useGradient ? t.e1 : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(t),
            )
          : _fallback(t),
    );
  }

  Widget _fallback(AppTokens t) {
    final color = fg ?? t.onAccent;
    if (label != null && label!.isNotEmpty) {
      return Center(
        child: Text(
          label!,
          style: TextStyle(
            color: color,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Icon(
      icon ?? Icons.auto_awesome_rounded,
      size: size * 0.52,
      color: color,
    );
  }
}
