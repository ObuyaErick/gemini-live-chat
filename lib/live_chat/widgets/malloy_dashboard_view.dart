import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:webs/live_chat/models/malloy_dashboard.dart';
import 'package:webs/live_chat/services/malloy_service.dart';
import 'package:webs/live_chat/widgets/data_chart.dart';
import 'package:webs/ui/core/app_theme.dart';

/// Renders a `kind: "malloy"` attachment: fetches the `malloy.dashboard.v1`
/// envelope from its signed `url` and shows it either as the visual dashboard
/// (KPI tiles, tagged charts, tables) or as the query behind it.
///
/// Unlike Plotly charts, Malloy dashboards carry **no** slot marker in the
/// prose (consumer guide §5.4) — this is rendered as its own panel alongside
/// the reply.
class MalloyDashboardView extends StatefulWidget {
  const MalloyDashboardView({super.key, required this.url, this.service});

  /// Signed URL of the dashboard envelope, from the attachment record.
  final String url;

  /// Injectable for tests; defaults to a plain [MalloyService].
  final MalloyService? service;

  @override
  State<MalloyDashboardView> createState() => _MalloyDashboardViewState();
}

enum _MalloyTab { dashboard, sql }

class _MalloyDashboardViewState extends State<MalloyDashboardView> {
  late final MalloyService _service = widget.service ?? MalloyService();

  MalloyDashboard? _dashboard;
  String? _error;
  _MalloyTab _tab = _MalloyTab.dashboard;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final dashboard = await _service.fetchDashboard(widget.url);
      if (!mounted) return;
      setState(() => _dashboard = dashboard);
    } on MalloyFetchException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: t.e1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_header(t), _body(t)],
      ),
    );
  }

  Widget _header(AppTokens t) {
    final dashboard = _dashboard;
    final title = dashboard == null
        ? 'Dashboard'
        : _humanize(dashboard.view.isEmpty ? 'Dashboard' : dashboard.view);
    final subtitle = dashboard == null
        ? null
        : [
            dashboard.package,
            dashboard.modelPath,
          ].where((s) => s.isNotEmpty).join(' / ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.space_dashboard_outlined, size: 15, color: t.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.text1,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.mono(size: 10, color: t.text3),
                  ),
              ],
            ),
          ),
          if (_dashboard != null) _tabToggle(t),
        ],
      ),
    );
  }

  /// Visual ⇄ SQL switch. Both views describe the same result, so this is a
  /// segmented toggle rather than a navigation affordance.
  Widget _tabToggle(AppTokens t) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in _MalloyTab.values)
            _ToggleChip(
              label: tab == _MalloyTab.dashboard ? 'Visual' : 'SQL',
              icon: tab == _MalloyTab.dashboard
                  ? Icons.insert_chart_outlined_rounded
                  : Icons.code_rounded,
              selected: _tab == tab,
              onTap: () => setState(() => _tab = tab),
            ),
        ],
      ),
    );
  }

  Widget _body(AppTokens t) {
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.danger),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.onAccent,
                elevation: 0,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final dashboard = _dashboard;
    if (dashboard == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
          ),
        ),
      );
    }

    return switch (_tab) {
      _MalloyTab.dashboard => _DashboardBody(dashboard: dashboard),
      _MalloyTab.sql => _SqlBody(dashboard: dashboard),
    };
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: selected ? t.accent : t.text3),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? t.text1 : t.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Visual representation --------------------------------------------------

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.dashboard});

  final MalloyDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (dashboard.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'This dashboard returned no rows.',
            style: TextStyle(fontSize: 12, color: t.text3),
          ),
        ),
      );
    }

    // A single-row result is the dashboard shape: scalar measures become KPI
    // tiles and each nested view becomes its own section. Multi-row results are
    // a plain result set — render them as one chart or table.
    if (dashboard.rows.length > 1) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: _viewFor(
          field: dashboard.view,
          rows: dashboard.rows,
          renderer: dashboard.rendererFor(dashboard.view),
        ),
      );
    }

    final row = dashboard.rows.first;
    final scalars = dashboard.scalarFields
        .where((f) => row.containsKey(f))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (scalars.isNotEmpty)
            // Equal-width tiles packed into as many columns as fit, so the KPI
            // band reads as a grid instead of a ragged stack.
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final columns = (constraints.maxWidth / 168).floor().clamp(
                  1,
                  4,
                );
                final tileWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final field in scalars)
                      SizedBox(
                        width: tileWidth,
                        child: _KpiTile(
                          label: _humanize(field),
                          value: row[field],
                        ),
                      ),
                  ],
                );
              },
            ),
          for (final field in dashboard.nestedFields) ...[
            const SizedBox(height: 18),
            Text(
              _humanize(field),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: t.text2,
              ),
            ),
            const SizedBox(height: 8),
            _viewFor(
              field: field,
              rows: MalloyDashboard.nestedRows(row, field),
              renderer: dashboard.rendererFor(field),
            ),
          ],
        ],
      ),
    );
  }

  /// Picks a rendering for one nested view: a chart when Malloy tagged it as
  /// one, a table otherwise.
  Widget _viewFor({
    required String field,
    required List<Map<String, dynamic>> rows,
    required String? renderer,
  }) {
    if (rows.isEmpty) return const _EmptyRows();
    final kind = switch (renderer) {
      'line_chart' || 'scatter_chart' => DataChartKind.line,
      'bar_chart' || 'column_chart' => DataChartKind.bar,
      _ => null,
    };
    if (kind == null) return _MalloyTable(rows: rows);

    final data = _ChartData.from(rows);
    // Hues are assigned in fixed order and never cycled, so past four measures
    // the table is the honest rendering.
    if (data == null || data.series.length > 4) return _MalloyTable(rows: rows);

    // Measures whose magnitudes are orders apart share no meaningful axis, and
    // a second y-axis is never the answer — facet into small multiples instead.
    if (data.needsFacet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, series) in data.series.indexed) ...[
            if (index > 0) const SizedBox(height: 14),
            _FacetLabel(text: series.name),
            DataChart(
              labels: data.labels,
              series: [series],
              kind: kind,
              height: 150,
            ),
          ],
        ],
      );
    }

    return DataChart(labels: data.labels, series: data.series, kind: kind);
  }
}

/// Categories and measures pulled out of a nested Malloy view: the first
/// non-numeric column is the category axis, every numeric column a measure.
class _ChartData {
  const _ChartData({required this.labels, required this.series});

  final List<String> labels;
  final List<ChartSeries> series;

  static _ChartData? from(List<Map<String, dynamic>> rows) {
    final fields = <String>[];
    for (final row in rows) {
      for (final key in row.keys) {
        if (!fields.contains(key) && row[key] is! List) fields.add(key);
      }
    }
    final numericFields = fields
        .where((f) => rows.any((r) => r[f] is num))
        .toList();
    if (fields.isEmpty || numericFields.isEmpty) return null;
    final categoryField = fields.firstWhere(
      (f) => !numericFields.contains(f),
      orElse: () => fields.first,
    );
    final measures = numericFields.where((f) => f != categoryField).toList();
    if (measures.isEmpty) return null;

    return _ChartData(
      labels: [for (final row in rows) _categoryLabel(row[categoryField])],
      series: [
        for (final measure in measures)
          ChartSeries(
            name: _humanize(measure),
            values: [
              for (final row in rows)
                row[measure] is num ? row[measure] as num : null,
            ],
          ),
      ],
    );
  }

  /// True when the largest measure dwarfs the smallest — e.g. revenue next to a
  /// conversion rate, where one series would flatten onto the axis.
  bool get needsFacet {
    if (series.length < 2) return false;
    final peaks = [for (final s in series) (s.maxValue ?? 0).abs().toDouble()]
      ..sort();
    if (peaks.first <= 0) return peaks.last > 0;
    return peaks.last / peaks.first > 25;
  }
}

class _FacetLabel extends StatelessWidget {
  const _FacetLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: AppTheme.mono(size: 9.5, color: t.text3)),
    );
  }
}

class _EmptyRows extends StatelessWidget {
  const _EmptyRows();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text('No rows.', style: TextStyle(fontSize: 12, color: t.text3));
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.mono(size: 9.5, color: t.text3),
          ),
          const SizedBox(height: 6),
          Text(
            _formatValue(value, compact: true),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: t.text1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MalloyTable extends StatelessWidget {
  const _MalloyTable({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final columns = <String>[];
    for (final row in rows) {
      for (final key in row.keys) {
        // Deeper nesting isn't rendered inline — it would need its own panel.
        if (!columns.contains(key) && row[key] is! List) columns.add(key);
      }
    }
    if (columns.isEmpty) return const _EmptyRows();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // A horizontal viewport hands its child unbounded width, so the rows
        // must size to their content — `stretch` here would demand infinite
        // width and corrupt the whole card's geometry. IntrinsicWidth keeps the
        // header band as wide as the widest row.
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: t.bg2,
                child: Row(
                  children: [
                    for (final column in columns)
                      _cell(
                        _humanize(column),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: t.text2,
                        ),
                      ),
                  ],
                ),
              ),
              for (final (index, row) in rows.indexed)
                Container(
                  decoration: BoxDecoration(
                    border: index == 0
                        ? null
                        : Border(top: BorderSide(color: t.border)),
                  ),
                  child: Row(
                    children: [
                      for (final column in columns)
                        _cell(
                          _formatValue(row[column]),
                          style: TextStyle(fontSize: 12, color: t.text1),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(String text, {required TextStyle style}) => Container(
    constraints: const BoxConstraints(minWidth: 96, maxWidth: 260),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    ),
  );
}

// ---- SQL representation -----------------------------------------------------

class _SqlBody extends StatelessWidget {
  const _SqlBody({required this.dashboard});

  final MalloyDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sql = dashboard.compiledSql;
    final source = sql ?? dashboard.query;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: sql == null ? t.warningSoft : t.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sql == null ? 'MALLOY SOURCE' : 'COMPILED SQL',
                  style: AppTheme.mono(
                    size: 9.5,
                    color: sql == null ? t.warning : t.accent,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Copy',
                iconSize: 15,
                visualDensity: VisualDensity.compact,
                onPressed: source.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: source));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            width: 160,
                          ),
                        );
                      },
                icon: Icon(Icons.copy_rounded, color: t.text3),
              ),
            ],
          ),
          if (sql == null) ...[
            const SizedBox(height: 4),
            Text(
              'This dashboard envelope carries no compiled SQL — showing the '
              'Malloy query that produced the result.',
              style: TextStyle(fontSize: 11.5, color: t.text3),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: t.bg3,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(11),
            ),
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                source.isEmpty ? '— not available —' : source,
                style: AppTheme.mono(size: 11.5, color: t.text1),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _meta('view', dashboard.view, t),
              _meta('package', dashboard.package, t),
              _meta('model', dashboard.modelPath, t),
              if (dashboard.requestId != null)
                _meta('request', dashboard.requestId!, t),
              if (dashboard.generatedAt != null)
                _meta(
                  'generated',
                  DateFormat.yMMMd().add_Hm().format(
                    dashboard.generatedAt!.toLocal(),
                  ),
                  t,
                ),
              _meta('rows', '${dashboard.rows.length}', t),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value, AppTokens t) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Text(
      '$label: $value',
      style: AppTheme.mono(size: 10, color: t.text3),
    );
  }
}

// ---- Shared formatting ------------------------------------------------------

String _humanize(String field) {
  final words = field
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'));
  return words
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Axis categories get a shorter form than table cells — a full `Jun 1, 2026`
/// per tick collides long before the axis runs out of room.
String _categoryLabel(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) {
      return DateFormat.MMMd().format(parsed);
    }
  }
  return _formatValue(value);
}

/// Formats a Malloy cell for display. [compact] shortens large numbers for KPI
/// tiles (`5.8M`) where the full figure would overflow.
String _formatValue(Object? value, {bool compact = false}) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is num) {
    if (compact && value.abs() >= 100000) {
      return NumberFormat.compact().format(value);
    }
    return value == value.roundToDouble() && value.abs() < 1e15
        ? NumberFormat.decimalPattern().format(value)
        : NumberFormat('#,##0.##').format(value);
  }
  final text = value.toString();
  // Malloy date/timestamp columns come across as ISO strings.
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text)) {
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return DateFormat.yMMMd().format(parsed);
  }
  return text;
}
