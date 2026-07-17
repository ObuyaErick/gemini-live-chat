import 'package:flutter/material.dart';
import 'package:webs/ui/core/app_theme.dart';

/// A suggested-question card shown in the empty state. Hover lifts to the
/// accent tint, matching the design system's suggestion grid.
class SuggestionCard extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const SuggestionCard({super.key, required this.text, required this.onTap});

  @override
  State<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<SuggestionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 268,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hover ? t.accentSoft : t.bg2,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _hover ? t.accentBorder : t.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined, size: 16, color: t.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: t.text1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
