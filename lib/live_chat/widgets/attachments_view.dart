import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/widgets/malloy_dashboard_view.dart';
import 'package:webs/live_chat/widgets/plotly_chart.dart';
import 'package:webs/ui/core/app_theme.dart';

class AttachmentsView extends StatelessWidget {
  final List<Attachment> attachments;

  const AttachmentsView({super.key, required this.attachments});

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in attachments)
          Padding(padding: const EdgeInsets.only(top: 12), child: _render(a)),
      ],
    );
  }

  /// Branches on the semantic `kind`, not the mime type — `plotly` and `malloy`
  /// are both JSON but render completely differently (consumer guide §8).
  Widget _render(Attachment a) {
    // Without a resolved URL there is nothing to fetch; fall through to the
    // chip, which degrades to a non-linked filename.
    if (a.hasUrl) {
      if (a.isMalloyDashboard) return MalloyDashboardView(url: a.url);
      if (a.isPlotlyJson) return PlotlyChart(url: a.url);
    }
    return _DownloadLink(attachment: a);
  }
}

class _DownloadLink extends StatelessWidget {
  final Attachment attachment;

  const _DownloadLink({required this.attachment});

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _ext() {
    final name = attachment.filename;
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      return name.substring(dot + 1).toUpperCase();
    }
    return 'FILE';
  }

  (Color, Color) _badgeColors(AppTokens t) {
    switch (_ext()) {
      case 'CSV':
      case 'XLSX':
        return (t.successSoft, t.success);
      case 'PDF':
        return (t.dangerSoft, t.danger);
      case 'JSON':
        return (t.warningSoft, t.warning);
      default:
        return (t.bg3, t.text2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = _formatSize(attachment.sizeBytes);
    final (badgeBg, badgeFg) = _badgeColors(t);
    return Material(
      color: t.bg2,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        // No URL means resolution failed server-side — leave the chip inert
        // rather than copying an empty link.
        onTap: !attachment.hasUrl
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: attachment.url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copied to clipboard'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    width: 220,
                  ),
                );
              },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: t.border),
          ),
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  _ext(),
                  style: AppTheme.mono(
                    size: 8.5,
                    weight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.text1,
                      ),
                    ),
                    if (size.isNotEmpty)
                      Text(
                        size,
                        style: TextStyle(fontSize: 11, color: t.text3),
                      ),
                  ],
                ),
              ),
              Icon(
                attachment.hasUrl
                    ? Icons.open_in_new_rounded
                    : Icons.link_off_rounded,
                size: 16,
                color: t.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
