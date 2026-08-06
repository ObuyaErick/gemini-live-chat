import 'dart:math' as math;

import 'package:flutter/material.dart';
// `intl` also exports a `TextDirection` (bidi) that shadows the painting one.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:webs/ui/core/app_theme.dart';

/// One measure plotted across the chart's categories.
class ChartSeries {
  const ChartSeries({required this.name, required this.values});

  final String name;

  /// Parallel to [DataChart.labels]; `null` is a gap, not a zero.
  final List<num?> values;

  num? get maxValue {
    num? max;
    for (final v in values) {
      if (v != null && (max == null || v > max)) max = v;
    }
    return max;
  }
}

enum DataChartKind { bar, line }

/// A small, Flutter-native categorical chart (bars or lines) drawn with
/// [CustomPaint].
///
/// Deliberately not a webview: Malloy dashboards nest charts inside a clipped
/// card, and platform views composite badly there on Flutter web — they paint
/// outside their container and collide with the surrounding widgets. Drawing on
/// the Flutter canvas keeps clipping, scrolling, and theming correct.
///
/// Identity is never colour-alone: two or more series always get a legend with
/// text-token labels, and a hover/tap read-out gives exact values.
class DataChart extends StatefulWidget {
  const DataChart({
    super.key,
    required this.labels,
    required this.series,
    this.kind = DataChartKind.bar,
    this.height = 220,
  });

  /// Category (x-axis) labels, already formatted for display.
  final List<String> labels;
  final List<ChartSeries> series;
  final DataChartKind kind;
  final double height;

  /// Categorical slots 1–4 of the validated palette, stepped per mode.
  static const _lightSeriesColors = [
    Color(0xFF2A78D6),
    Color(0xFFEB6834),
    Color(0xFF1BAF7A),
    Color(0xFFEDA100),
  ];
  static const _darkSeriesColors = [
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
  ];

  /// Hues are assigned in fixed order and never cycled — past four series the
  /// caller must facet rather than repaint.
  static List<Color> paletteFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkSeriesColors : _lightSeriesColors;

  @override
  State<DataChart> createState() => _DataChartState();
}

class _DataChartState extends State<DataChart> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final palette = DataChart.paletteFor(Theme.of(context).brightness);
    final visible = widget.series.take(palette.length).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A single series is named by the section heading above it, so a legend
        // would only repeat it.
        if (visible.length > 1) ...[
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final (index, series) in visible.indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: palette[index],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      series.name,
                      style: TextStyle(fontSize: 11.5, color: t.text2),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return MouseRegion(
                onHover: (event) =>
                    _updateHover(event.localPosition.dx, constraints.maxWidth),
                onExit: (_) => setState(() => _hoverIndex = null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _updateHover(
                    details.localPosition.dx,
                    constraints.maxWidth,
                  ),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, widget.height),
                    painter: _ChartPainter(
                      labels: widget.labels,
                      series: visible,
                      kind: widget.kind,
                      palette: palette,
                      gridColor: t.border,
                      textColor: t.text3,
                      surfaceColor: t.surface,
                      hoverIndex: _hoverIndex,
                    ),
                    child: _hoverIndex == null
                        ? null
                        : _Readout(
                            label: widget.labels[_hoverIndex!],
                            series: visible,
                            palette: palette,
                            index: _hoverIndex!,
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _updateHover(double dx, double width) {
    if (widget.labels.isEmpty) return;
    final plotWidth = width - _ChartPainter.padLeft - _ChartPainter.padRight;
    if (plotWidth <= 0) return;
    final ratio = ((dx - _ChartPainter.padLeft) / plotWidth).clamp(0.0, 1.0);
    final index = (ratio * widget.labels.length).floor().clamp(
      0,
      widget.labels.length - 1,
    );
    if (index != _hoverIndex) setState(() => _hoverIndex = index);
  }
}

/// Value read-out for the hovered category, pinned to the top of the plot.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.series,
    required this.palette,
    required this.index,
  });

  final String label;
  final List<ChartSeries> series;
  final List<Color> palette;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: const EdgeInsets.only(right: 4, top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(8),
          boxShadow: t.e1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTheme.mono(size: 9.5, color: t.text3)),
            for (final (slot, s) in series.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: palette[slot],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formatAxisValue(
                        index < s.values.length ? s.values[index] : null,
                      ),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: t.text1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.labels,
    required this.series,
    required this.kind,
    required this.palette,
    required this.gridColor,
    required this.textColor,
    required this.surfaceColor,
    required this.hoverIndex,
  });

  static const padLeft = 52.0;
  static const padRight = 12.0;
  static const padTop = 10.0;
  static const padBottom = 26.0;

  final List<String> labels;
  final List<ChartSeries> series;
  final DataChartKind kind;
  final List<Color> palette;
  final Color gridColor;
  final Color textColor;
  final Color surfaceColor;
  final int? hoverIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      padLeft,
      padTop,
      size.width - padRight,
      size.height - padBottom,
    );
    if (plot.width <= 0 || plot.height <= 0 || labels.isEmpty) return;

    final (minValue, maxValue, step) = _scale();
    double y(num value) =>
        plot.bottom -
        ((value - minValue) / (maxValue - minValue)) * plot.height;

    // Recessive grid: hairlines behind the marks, labelled on the left.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var value = minValue; value <= maxValue + step / 2; value += step) {
      final gy = y(value);
      canvas.drawLine(Offset(plot.left, gy), Offset(plot.right, gy), grid);
      _text(
        canvas,
        formatAxisValue(value, compact: true),
        Offset(plot.left - 8, gy),
        align: TextAlign.right,
        maxWidth: padLeft - 12,
        anchorRight: true,
      );
    }

    final bandWidth = plot.width / labels.length;

    if (hoverIndex != null) {
      final hx = plot.left + bandWidth * (hoverIndex! + 0.5);
      canvas.drawLine(
        Offset(hx, plot.top),
        Offset(hx, plot.bottom),
        Paint()
          ..color = gridColor
          ..strokeWidth = 2,
      );
    }

    switch (kind) {
      case DataChartKind.bar:
        _paintBars(canvas, plot, bandWidth, y);
      case DataChartKind.line:
        _paintLines(canvas, plot, bandWidth, y);
    }

    _paintCategoryLabels(canvas, plot, bandWidth);
  }

  void _paintBars(
    Canvas canvas,
    Rect plot,
    double bandWidth,
    double Function(num) y,
  ) {
    const groupGap = 6.0;
    const barGap = 2.0; // surface gap between adjacent fills
    final available = bandWidth - groupGap - barGap * (series.length - 1);
    // Few categories shouldn't yield slab-wide bars; cap and centre the group.
    final barWidth = math.max(2.0, math.min(76.0, available / series.length));
    final groupWidth = barWidth * series.length + barGap * (series.length - 1);
    final groupInset = (bandWidth - groupWidth) / 2;

    for (final (slot, s) in series.indexed) {
      final paint = Paint()..color = palette[slot];
      for (var i = 0; i < labels.length; i++) {
        final value = i < s.values.length ? s.values[i] : null;
        if (value == null) continue;
        final left =
            plot.left + bandWidth * i + groupInset + slot * (barWidth + barGap);
        final top = y(value);
        final baseline = y(0 > _scale().$1 ? 0 : _scale().$1);
        final rect = Rect.fromLTRB(
          left,
          math.min(top, baseline),
          left + barWidth,
          math.max(top, baseline),
        );
        // 4px rounded data-end, square where it meets the baseline.
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          hoverIndex == null || hoverIndex == i
              ? paint
              : (Paint()..color = palette[slot].withValues(alpha: 0.45)),
        );
      }
    }
  }

  void _paintLines(
    Canvas canvas,
    Rect plot,
    double bandWidth,
    double Function(num) y,
  ) {
    for (final (slot, s) in series.indexed) {
      final stroke = Paint()
        ..color = palette[slot]
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      var started = false;
      final points = <Offset>[];
      for (var i = 0; i < labels.length; i++) {
        final value = i < s.values.length ? s.values[i] : null;
        if (value == null) {
          started = false; // a gap breaks the line rather than interpolating
          continue;
        }
        final point = Offset(plot.left + bandWidth * (i + 0.5), y(value));
        points.add(point);
        if (started) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          started = true;
        }
      }
      canvas.drawPath(path, stroke);

      // Markers only when they can breathe (≥8px) — plus the hovered point.
      final showAll = points.length <= 24;
      for (var i = 0; i < labels.length; i++) {
        if (!showAll && hoverIndex != i) continue;
        final value = i < s.values.length ? s.values[i] : null;
        if (value == null) continue;
        final center = Offset(plot.left + bandWidth * (i + 0.5), y(value));
        canvas.drawCircle(center, 4.5, Paint()..color = surfaceColor);
        canvas.drawCircle(center, 4, Paint()..color = palette[slot]);
      }
    }
  }

  void _paintCategoryLabels(Canvas canvas, Rect plot, double bandWidth) {
    // Thin the ticks out by how wide the labels actually are, so long category
    // names (dates especially) never collide.
    final slotWidth = math.min(140.0, _widestLabel() + 32);
    final maxLabels = math.max(1, (plot.width / slotWidth).floor());
    final stride = (labels.length / maxLabels).ceil();
    for (var i = 0; i < labels.length; i++) {
      // Ticks land on stride multiples only — forcing the last one in as well
      // is what makes the right-hand end of the axis collide.
      if (i % stride != 0) continue;
      _text(
        canvas,
        labels[i],
        Offset(plot.left + bandWidth * (i + 0.5), plot.bottom + 6),
        align: TextAlign.center,
        maxWidth: slotWidth,
        centered: true,
        topAligned: true,
        clampTo: plot,
      );
    }
  }

  double _widestLabel() {
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(fontSize: 10)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
    }
    return widest;
  }

  /// Baseline, top, and gridline step for the value axis. Bars are anchored at
  /// zero; lines get a padded band so a flat series isn't a line on the floor.
  (double, double, double) _scale() {
    var maxValue = 0.0;
    var minValue = 0.0;
    var seen = false;
    for (final s in series) {
      for (final v in s.values) {
        if (v == null) continue;
        final value = v.toDouble();
        maxValue = seen ? math.max(maxValue, value) : value;
        minValue = seen ? math.min(minValue, value) : value;
        seen = true;
      }
    }
    if (!seen) return (0, 1, 0.5);
    if (kind == DataChartKind.bar || minValue > 0) {
      minValue = math.min(0, minValue);
    }
    if (maxValue == minValue) maxValue = minValue + 1;
    final step = _niceStep((maxValue - minValue) / 4);
    final niceMin = (minValue / step).floor() * step;
    final niceMax = (maxValue / step).ceil() * step;
    return (niceMin, niceMax, step);
  }

  static double _niceStep(double rough) {
    if (rough <= 0) return 1;
    final magnitude = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final normalised = rough / magnitude;
    final multiplier = normalised <= 1
        ? 1.0
        : normalised <= 2
        ? 2.0
        : normalised <= 5
        ? 5.0
        : 10.0;
    return multiplier * magnitude;
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required TextAlign align,
    required double maxWidth,
    bool anchorRight = false,
    bool centered = false,
    bool topAligned = false,
    Rect? clampTo,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, color: textColor),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    var dx = anchorRight
        ? at.dx - painter.width
        : centered
        ? at.dx - painter.width / 2
        : at.dx;
    // Keep edge ticks inside the plot rather than letting them bleed past the
    // card's clip.
    if (clampTo != null) {
      dx = dx.clamp(
        clampTo.left - 6,
        math.max(clampTo.left - 6, clampTo.right - painter.width + 6),
      );
    }
    final dy = topAligned ? at.dy : at.dy - painter.height / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.hoverIndex != hoverIndex ||
      old.series != series ||
      old.labels != labels ||
      old.palette != palette ||
      old.gridColor != gridColor;
}

/// Axis/read-out number formatting: compact on the axis (`1.4M`), full in the
/// read-out where the exact figure matters.
String formatAxisValue(num? value, {bool compact = false}) {
  if (value == null) return '—';
  if (compact && value.abs() >= 1000) {
    return NumberFormat.compact().format(value);
  }
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return NumberFormat.decimalPattern().format(value);
  }
  return NumberFormat('#,##0.##').format(value);
}
