import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/live_chat/widgets/plotly_chart.dart';

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
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: a.isPlotlyJson
                ? PlotlyChart(url: a.url)
                : _DownloadLink(attachment: a),
          ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final size = _formatSize(attachment.sizeBytes);
    return Material(
      color: const Color(0xFFF6F7FB),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.attach_file_rounded,
                size: 18,
                color: Color(0xFF1F2330),
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2330),
                      ),
                    ),
                    Text(
                      [
                        attachment.mimeType,
                        if (size.isNotEmpty) size,
                      ].join('  •  '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF747787),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: Color(0xFF747787),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
