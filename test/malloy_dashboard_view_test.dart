import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webs/live_chat/models/malloy_dashboard.dart';
import 'package:webs/live_chat/services/malloy_service.dart';
import 'package:webs/live_chat/widgets/data_chart.dart';
import 'package:webs/live_chat/widgets/malloy_dashboard_view.dart';

/// Serves a fixed envelope so the panel can be laid out without any I/O.
class _StubMalloyService implements MalloyService {
  _StubMalloyService(this.dashboard);

  final MalloyDashboard dashboard;

  @override
  Future<MalloyDashboard> fetchDashboard(String url) async => dashboard;
}

MalloyDashboard _dashboard({bool nested = true}) => MalloyDashboard.fromJson({
  'schema': 'malloy.dashboard.v1',
  'package': 'bi_chat',
  'model_path': 'kpi.malloy',
  'view': 'kpi_executive_summary',
  'query': 'run: kpi -> kpi_executive_summary',
  'view_meta': {
    'name': 'kpi_executive_summary',
    'fields': [
      {
        'name': 'revenue_trend',
        'tags': ['# line_chart'],
      },
      {
        'name': 'revenue_by_channel',
        'tags': ['# bar_chart'],
      },
    ],
  },
  'result': {
    'rows': [
      {
        'total_revenue': 1374025.92,
        'total_sessions': 594684.24,
        'total_orders': 21157.23,
        'avg_order_value': 64.94,
        'conversion_rate': 0.0356,
        if (nested) ...{
          'revenue_trend': [
            for (var day = 1; day <= 30; day++)
              {
                'day': '2026-06-${day.toString().padLeft(2, '0')}',
                'revenue': 40000 + day * 900,
              },
          ],
          'revenue_by_channel': [
            {'channel': 'organic', 'revenue': 620000},
            {'channel': 'paid', 'revenue': 410000},
            {'channel': 'email', 'revenue': 344025},
          ],
          'top_categories': [
            {'category': 'shoes', 'revenue': 900000, 'orders': 12000},
          ],
        },
      },
    ],
  },
});

Widget _host(Widget child, {double width = 620}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(child: child),
      ),
    ),
  ),
);

void main() {
  group('MalloyDashboardView', () {
    testWidgets('lays out tiles, charts and tables without overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MalloyDashboardView(
            url: 'https://example.test/dashboard.json',
            service: _StubMalloyService(_dashboard()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header identity plus both halves of the toggle.
      expect(find.text('Kpi Executive Summary'), findsOneWidget);
      expect(find.text('bi_chat / kpi.malloy'), findsOneWidget);
      expect(find.text('Visual'), findsOneWidget);
      expect(find.text('SQL'), findsOneWidget);

      // KPI tiles for the scalar measures.
      expect(find.text('TOTAL REVENUE'), findsOneWidget);
      expect(find.text('1.37M'), findsOneWidget);

      // Tagged nested views become charts; the untagged one stays a table.
      expect(find.byType(DataChart), findsNWidgets(2));
      expect(find.text('Top Categories'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in a narrow bubble without overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MalloyDashboardView(
            url: 'https://example.test/dashboard.json',
            service: _StubMalloyService(_dashboard()),
          ),
          width: 300,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('toggles to the query behind the dashboard', (tester) async {
      await tester.pumpWidget(
        _host(
          MalloyDashboardView(
            url: 'https://example.test/dashboard.json',
            service: _StubMalloyService(_dashboard(nested: false)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('run: kpi -> kpi_executive_summary'), findsNothing);

      await tester.tap(find.text('SQL'));
      await tester.pumpAndSettle();

      // No compiled SQL in this envelope — the Malloy source stands in, badged.
      expect(find.text('MALLOY SOURCE'), findsOneWidget);
      expect(find.text('run: kpi -> kpi_executive_summary'), findsOneWidget);
      expect(find.text('TOTAL REVENUE'), findsNothing);

      await tester.tap(find.text('Visual'));
      await tester.pumpAndSettle();
      expect(find.text('TOTAL REVENUE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('surfaces a fetch failure with a retry', (tester) async {
      await tester.pumpWidget(
        _host(
          MalloyDashboardView(
            url: 'https://example.test/dashboard.json',
            service: _FailingService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('expired'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('DataChart', () {
    testWidgets('draws bars and a legend for two series', (tester) async {
      await tester.pumpWidget(
        _host(
          const DataChart(
            labels: ['organic', 'paid', 'email'],
            series: [
              ChartSeries(name: 'Revenue', values: [620000, 410000, 344025]),
              ChartSeries(name: 'Orders', values: [900, 610, 480]),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Revenue'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tolerates gaps and an all-equal series', (tester) async {
      await tester.pumpWidget(
        _host(
          const DataChart(
            labels: ['a', 'b', 'c'],
            series: [
              ChartSeries(name: 'Flat', values: [5, null, 5]),
            ],
            kind: DataChartKind.line,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A single series is named by its section heading — no legend box.
      expect(find.text('Flat'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FailingService implements MalloyService {
  @override
  Future<MalloyDashboard> fetchDashboard(String url) async =>
      throw const MalloyFetchException(
        'This dashboard link has expired — reconnect to refresh it.',
      );
}
