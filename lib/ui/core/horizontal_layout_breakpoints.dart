import 'package:flutter/material.dart';

class HorizontalBreakpoints {
  int xxs, xs, sm, md, lg, xl;
  HorizontalBreakpoints({
    this.xxs = 240,
    this.xs = 320,
    this.sm = 640,
    this.md = 768,
    this.lg = 1024,
    this.xl = 1280,
  });
}

class HorizontalLayoutBreakpoints extends StatelessWidget {
  final HorizontalBreakpoints _breakPoints;
  final Widget Function(BuildContext context, double maxWidth) all;
  final Widget Function(BuildContext context, double maxWidth)? xxs;
  final Widget Function(BuildContext context, double maxWidth)? xs;
  final Widget Function(BuildContext context, double maxWidth)? sm;
  final Widget Function(BuildContext context, double maxWidth)? md;
  final Widget Function(BuildContext context, double maxWidth)? lg;
  final Widget Function(BuildContext context, double maxWidth)? xl;
  HorizontalLayoutBreakpoints({
    super.key,
    HorizontalBreakpoints? breakPoints,
    required this.all,
    this.xxs,
    this.xs,
    this.sm,
    this.md,
    this.lg,
    this.xl,
  }) : _breakPoints = breakPoints ?? HorizontalBreakpoints();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= _breakPoints.xl && xl != null) {
          return xl!(context, width);
        }
        if (width >= _breakPoints.lg && lg != null) {
          return lg!(context, width);
        }
        if (width >= _breakPoints.md && md != null) {
          return md!(context, width);
        }
        if (width >= _breakPoints.sm && sm != null) {
          return sm!(context, width);
        }
        if (width >= _breakPoints.xs && xs != null) {
          return xs!(context, width);
        }
        if (width >= _breakPoints.xxs && xxs != null) {
          return xxs!(context, width);
        }
        return all(context, width);
      },
    );
  }
}
