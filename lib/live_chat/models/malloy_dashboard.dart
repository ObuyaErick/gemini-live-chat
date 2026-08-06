/// The `malloy.dashboard.v1` envelope delivered as a `kind: "malloy"`
/// attachment by the `MALLOY_ANALYTICS` tool (consumer guide §5.4).
///
/// The envelope carries the **complete**, untrimmed result set — the rows
/// inlined on the `tool_result` frame are capped at 20 precisely because this
/// artifact holds the full detail. [viewMeta] carries the view's Malloy render
/// tags so a renderer can pick a layout per nested view.
class MalloyDashboard {
  /// Envelope schema discriminator, e.g. `malloy.dashboard.v1`.
  final String schema;

  /// Malloy package the view lives in, e.g. `bi_chat`.
  final String package;

  /// Model file within the package, e.g. `kpi.malloy`.
  final String modelPath;

  /// Name of the dashboard-tagged view that produced this result.
  final String view;

  /// The Malloy source that was run, e.g. `run: kpi -> kpi_executive_summary`.
  final String query;

  /// Render tags and nested-view metadata for [view]. Shape is server-defined
  /// and treated as opaque here — [rendererFor] probes it defensively.
  final Map<String, dynamic> viewMeta;

  final DateTime? generatedAt;
  final String? requestId;

  /// The full result set. Values are Malloy-shaped: scalars for measures and
  /// dimensions, and a `List<Map>` for a nested view.
  final List<Map<String, dynamic>> rows;

  /// The compiled SQL behind [query], when the server ships it.
  ///
  /// This is **not** part of the documented `malloy.dashboard.v1` contract, so
  /// it is looked up across the field names the compiler is known to emit and
  /// is `null` when absent — the SQL tab falls back to the Malloy source.
  final String? compiledSql;

  const MalloyDashboard({
    required this.schema,
    required this.package,
    required this.modelPath,
    required this.view,
    required this.query,
    required this.viewMeta,
    required this.rows,
    this.generatedAt,
    this.requestId,
    this.compiledSql,
  });

  factory MalloyDashboard.fromJson(Map<String, dynamic> json) {
    final result =
        (json['result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final viewMeta =
        (json['view_meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MalloyDashboard(
      schema: (json['schema'] as String?) ?? '',
      package: (json['package'] as String?) ?? '',
      modelPath: (json['model_path'] as String?) ?? '',
      view: (json['view'] as String?) ?? '',
      query: (json['query'] as String?) ?? '',
      viewMeta: viewMeta,
      generatedAt: DateTime.tryParse((json['generated_at'] as String?) ?? ''),
      requestId: json['request_id'] as String?,
      rows: _rowsOf(result['rows']),
      compiledSql: _firstString(
        const ['sql', 'compiled_sql', 'sql_text'],
        [json, result, viewMeta],
      ),
    );
  }

  static List<Map<String, dynamic>> _rowsOf(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((r) => r.cast<String, dynamic>())
        .toList(growable: false);
  }

  static String? _firstString(
    List<String> keys,
    List<Map<String, dynamic>> sources,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        final value = source[key];
        if (value is String && value.trim().isNotEmpty) return value;
      }
    }
    return null;
  }

  /// Column names of [rows] whose values are scalars (measures/dimensions).
  List<String> get scalarFields => _fields(nested: false);

  /// Column names of [rows] that hold a nested view (a `List<Map>`).
  List<String> get nestedFields => _fields(nested: true);

  List<String> _fields({required bool nested}) {
    final out = <String>[];
    for (final row in rows) {
      for (final entry in row.entries) {
        if (out.contains(entry.key)) continue;
        if ((entry.value is List) == nested) out.add(entry.key);
      }
    }
    return out;
  }

  /// Rows of the nested view stored under [field] across the whole result.
  static List<Map<String, dynamic>> nestedRows(
    Map<String, dynamic> row,
    String field,
  ) => _rowsOf(row[field]);

  /// The Malloy render tag that applies to [field], e.g. `line_chart`.
  ///
  /// Malloy tags are emitted in several shapes depending on compiler version
  /// (`"# line_chart"`, `{"renderer": "line_chart"}`, `{"tags": [...]}`), so
  /// this walks [viewMeta] looking for any known renderer name associated with
  /// [field]. Returns `null` when the view carries no render hint — render a
  /// table in that case.
  String? rendererFor(String field) {
    final scope = _metaFor(viewMeta, field);
    if (scope == null) return null;
    return _knownRendererIn(scope);
  }

  static const _renderers = {
    'line_chart',
    'bar_chart',
    'column_chart',
    'scatter_chart',
    'table',
    'list',
    'list_detail',
  };

  /// Depth-first search for the metadata node describing [field].
  static Object? _metaFor(Object? node, String field) {
    if (node is Map) {
      if (node['name'] == field) return node;
      if (node.containsKey(field)) return node[field];
      for (final value in node.values) {
        final hit = _metaFor(value, field);
        if (hit != null) return hit;
      }
    } else if (node is List) {
      for (final value in node) {
        final hit = _metaFor(value, field);
        if (hit != null) return hit;
      }
    }
    return null;
  }

  static String? _knownRendererIn(Object? node) {
    if (node is String) {
      final normalised = node.replaceAll('#', '').trim();
      return _renderers.contains(normalised) ? normalised : null;
    }
    if (node is List) {
      for (final value in node) {
        final hit = _knownRendererIn(value);
        if (hit != null) return hit;
      }
    }
    if (node is Map) {
      for (final entry in node.entries) {
        // Skip the nested-view payload itself; only tag-ish keys carry hints.
        if (entry.key == 'fields' || entry.key == 'rows') continue;
        final hit = _knownRendererIn(entry.value);
        if (hit != null) return hit;
      }
    }
    return null;
  }
}
