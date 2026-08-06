import 'package:flutter_test/flutter_test.dart';
import 'package:webs/live_chat/models/attachment.dart';
import 'package:webs/live_chat/models/malloy_dashboard.dart';

void main() {
  group('MalloyDashboard.fromJson', () {
    final envelope = <String, dynamic>{
      'schema': 'malloy.dashboard.v1',
      'package': 'bi_chat',
      'model_path': 'kpi.malloy',
      'view': 'kpi_executive_summary',
      'query': 'run: kpi -> kpi_executive_summary',
      'view_meta': {
        'name': 'kpi_executive_summary',
        'dashboard': true,
        'fields': [
          {'name': 'total_revenue'},
          {
            'name': 'revenue_by_month',
            'tags': ['# line_chart'],
          },
          {'name': 'top_categories'},
        ],
      },
      'generated_at': '2026-07-01T10:15:42Z',
      'request_id': 'a1b2c3d4e5f6',
      'result': {
        'rows': [
          {
            'total_revenue': 5820000,
            'total_sessions': 1890000,
            'revenue_by_month': [
              {'month': '2026-01-01', 'revenue': 410000},
              {'month': '2026-02-01', 'revenue': 455000},
            ],
            'top_categories': [
              {'category': 'shoes', 'revenue': 900000},
            ],
          },
        ],
      },
    };

    test('parses the envelope metadata and full row set', () {
      final dashboard = MalloyDashboard.fromJson(envelope);

      expect(dashboard.schema, 'malloy.dashboard.v1');
      expect(dashboard.package, 'bi_chat');
      expect(dashboard.modelPath, 'kpi.malloy');
      expect(dashboard.view, 'kpi_executive_summary');
      expect(dashboard.requestId, 'a1b2c3d4e5f6');
      expect(dashboard.generatedAt, isNotNull);
      expect(dashboard.rows, hasLength(1));
    });

    test('separates scalar measures from nested views', () {
      final dashboard = MalloyDashboard.fromJson(envelope);

      expect(dashboard.scalarFields, ['total_revenue', 'total_sessions']);
      expect(dashboard.nestedFields, ['revenue_by_month', 'top_categories']);
      expect(
        MalloyDashboard.nestedRows(dashboard.rows.first, 'revenue_by_month'),
        hasLength(2),
      );
    });

    test('resolves Malloy render tags per nested view', () {
      final dashboard = MalloyDashboard.fromJson(envelope);

      expect(dashboard.rendererFor('revenue_by_month'), 'line_chart');
      expect(dashboard.rendererFor('top_categories'), isNull);
      expect(dashboard.rendererFor('not_a_field'), isNull);
    });

    test('compiledSql is null when the envelope omits it', () {
      expect(MalloyDashboard.fromJson(envelope).compiledSql, isNull);
    });

    test('compiledSql is picked up wherever the server places it', () {
      final withSql = Map<String, dynamic>.from(envelope)
        ..['result'] = {
          ...envelope['result'] as Map<String, dynamic>,
          'compiled_sql': 'SELECT 1',
        };

      expect(MalloyDashboard.fromJson(withSql).compiledSql, 'SELECT 1');
    });

    test('tolerates a malformed envelope', () {
      final dashboard = MalloyDashboard.fromJson(const {});

      expect(dashboard.rows, isEmpty);
      expect(dashboard.view, '');
      expect(dashboard.rendererFor('anything'), isNull);
    });
  });

  group('Attachment kinds', () {
    Attachment of(String? kind, String mime) => Attachment.fromJson({
      'file_id': 'f',
      'filename': 'a.json',
      'mime_type': mime,
      'kind': ?kind,
      'url': 'https://example.test/a.json',
    });

    test('classifies malloy dashboards on kind', () {
      final att = of('malloy', 'application/vnd.malloy.dashboard+json');
      expect(att.isMalloyDashboard, isTrue);
      expect(att.isPlotlyJson, isFalse);
    });

    test('falls back to mime type when kind is absent', () {
      expect(
        of(null, 'application/vnd.malloy.dashboard+json').isMalloyDashboard,
        isTrue,
      );
      expect(of(null, 'application/json').isPlotlyJson, isTrue);
      expect(of(null, 'application/json').isMalloyDashboard, isFalse);
    });

    test('hasUrl guards an omitted url', () {
      final att = Attachment.fromJson(const {
        'file_id': 'f',
        'filename': 'a.json',
        'mime_type': 'application/json',
      });
      expect(att.hasUrl, isFalse);
    });

    test('carries resource_id through', () {
      final att = Attachment.fromJson(const {
        'file_id': 'f',
        'filename': 'q1.md',
        'mime_type': 'text/markdown',
        'kind': 'editable',
        'url': 'https://example.test/q1.md',
        'resource_id': 'kc-123',
      });
      expect(att.resourceId, 'kc-123');
    });
  });
}
