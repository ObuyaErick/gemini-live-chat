import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class PlotlyChart extends StatefulWidget {
  final String url;
  final double height;

  const PlotlyChart({super.key, required this.url, this.height = 380});

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
      final res = await http.get(Uri.parse(widget.url));
      if (res.statusCode != 200) {
        throw Exception('${res.statusCode} ${res.reasonPhrase ?? ''}');
      }
      jsonDecode(res.body); // validate
      if (!mounted) return;

      final controller = WebViewController()
        // ..setBackgroundColor(Colors.white)
        ..loadHtmlString(_buildHtml(res.body));

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
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9EAF0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _error != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB42318),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              )
            : _controller == null
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : WebViewWidget(controller: _controller!),
      ),
    );
  }
}
