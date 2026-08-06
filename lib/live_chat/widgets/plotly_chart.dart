import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webs/ui/core/app_theme.dart';

class PlotlyChart extends StatefulWidget {
  /// Signed URL of a Plotly figure JSON attachment. Empty when the figure was
  /// supplied directly via [PlotlyChart.fromFigure].
  final String url;

  /// A pre-built Plotly figure (`{data, layout, config}`) to render without a
  /// network round-trip — used by the Malloy renderer, which derives figures
  /// from rows it already holds.
  final String? figureJson;

  final double height;

  /// Card header label and badge.
  final String title;
  final String badge;

  const PlotlyChart({
    super.key,
    required this.url,
    this.height = 380,
    this.title = 'Chart',
    this.badge = 'Plotly',
  }) : figureJson = null;

  const PlotlyChart.fromFigure({
    super.key,
    required String figure,
    this.height = 320,
    this.title = 'Chart',
    this.badge = 'Malloy',
  }) : figureJson = figure,
       url = '';

  @override
  State<PlotlyChart> createState() => _PlotlyChartState();
}

class _PlotlyChartState extends State<PlotlyChart> {
  WebViewController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final String figure;
      final inline = widget.figureJson;
      if (inline != null) {
        figure = inline;
      } else {
        final res = await http.get(Uri.parse(widget.url));
        if (res.statusCode != 200) {
          throw Exception('${res.statusCode} ${res.reasonPhrase ?? ''}');
        }
        figure = res.body;
      }
      jsonDecode(figure); // validate
      if (!mounted) return;

      final controller = WebViewController()
        // ..setBackgroundColor(Colors.white)
        ..loadHtmlString(_buildHtml(figure));

      setState(() => _controller = controller);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load chart: $e');
    }
  }

  String _buildHtml(String figureJson) {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="https://cdn.plot.ly/plotly-2.35.2.min.js" charset="utf-8"></script>
<style>
  html, body { margin: 0; padding: 0; height: 100%; background: #fff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
  #chart { width: 100%; height: 100%; }
  #err { color: #B42318; font-size: 12px; padding: 16px; }
</style>
</head>
<body>
<div id="chart"></div>
<div id="err"></div>
<script>
  (function () {
    function render() {
      try {
        var fig = $figureJson;
        Plotly.newPlot(
          'chart',
          fig.data || [],
          Object.assign({ autosize: true, margin: { t: 30, r: 20, b: 40, l: 50 } }, fig.layout || {}),
          { responsive: true, displaylogo: false }
        );
      } catch (e) {
        document.getElementById('err').textContent = 'Render failed: ' + e.message;
      }
    }
    if (window.Plotly) { render(); }
    else {
      var tries = 0;
      var iv = setInterval(function () {
        if (window.Plotly) { clearInterval(iv); render(); }
        else if (++tries > 60) { clearInterval(iv); document.getElementById('err').textContent = 'Plotly failed to load'; }
      }, 100);
    }
  })();
</script>
</body>
</html>
''';
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
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.insert_chart_outlined_rounded,
                  size: 15,
                  color: t.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.text1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: t.bg3,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.badge,
                    style: AppTheme.mono(size: 10, color: t.text3),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: widget.height,
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: TextStyle(fontSize: 12, color: t.danger),
                          textAlign: TextAlign.center,
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
                  )
                : _controller == null
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    ),
                  )
                : WebViewWidget(controller: _controller!),
          ),
        ],
      ),
    );
  }
}
