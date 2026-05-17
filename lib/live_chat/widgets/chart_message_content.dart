import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/widgets/plotly_chart.dart';

// Splits model content on ```chart\n<file_id>\n``` slot markers and renders
// each Plotly chart in-place within the prose (per Section 8 of the API guide).
class ChartMessageContent extends StatelessWidget {
  static final _slotRe = RegExp(
    r'```chart\n([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\n```',
  );

  final String content;
  final List<Attachment> attachments;
  final MarkdownStyleSheet? styleSheet;

  const ChartMessageContent({
    super.key,
    required this.content,
    required this.attachments,
    this.styleSheet,
  });

  List<_Segment> _parse() {
    final segments = <_Segment>[];
    int last = 0;
    for (final m in _slotRe.allMatches(content)) {
      if (m.start > last) {
        segments.add(_Segment.text(content.substring(last, m.start)));
      }
      segments.add(_Segment.chart(m.group(1)!));
      last = m.end;
    }
    if (last < content.length) {
      segments.add(_Segment.text(content.substring(last)));
    }
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final a in attachments) a.fileId: a};
    final segments = _parse();

    if (segments.isEmpty) return const SizedBox.shrink();

    // If there are no chart slots at all, skip the split overhead.
    if (segments.length == 1 && segments.first.isText) {
      return MarkdownBody(data: segments.first.value, styleSheet: styleSheet);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final seg in segments)
          if (seg.isText) ...[
            if (seg.value.trim().isNotEmpty)
              MarkdownBody(data: seg.value, styleSheet: styleSheet),
          ] else ...[
            const SizedBox(height: 12),
            if (byId[seg.value]?.isPlotlyJson == true)
              PlotlyChart(url: byId[seg.value]!.url)
            else
              const SizedBox.shrink(),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _Segment {
  final bool isText;
  final String value;

  const _Segment.text(this.value) : isText = true;
  const _Segment.chart(this.value) : isText = false;
}
