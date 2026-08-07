import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webs/ui/core/alerts/app_notification.dart';
import 'package:webs/ui/core/alerts/notification_host.dart';
import 'package:webs/ui/core/alerts/notification_position.dart';
import 'package:webs/ui/core/alerts/notification_severity.dart';

/// A descendant of [NotificationHost] that exposes its delegate via a button,
/// mirroring how a real screen (a `Builder` capturing the delegate, or any
/// widget below the host) pushes toasts.
class _Pusher extends StatelessWidget {
  const _Pusher({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => NotificationHost.of(context).pushAlert(notification),
      child: const Text('push'),
    );
  }
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: NotificationHost(child: child)),
);

/// Mirrors how `live_chat_screen.dart` actually mounts the host: wrapping
/// the *whole* [Scaffold] (not the reverse, as [_host] does) — so the toast
/// overlay is a sibling of the [Scaffold], not a descendant of the
/// [Material] the [Scaffold] provides for its own body. The [Scaffold]'s
/// body below also carries a `Row`/[Expanded] layout, matching the real
/// screen's `_buildChatArea` — this is what previously overflowed when the
/// host's [Stack] gave it loose rather than tight constraints.
Widget _hostWrappingScaffold(Widget pushButton) => MaterialApp(
  home: NotificationHost(
    child: Scaffold(
      body: SizedBox(
        height: 600,
        child: Row(
          children: [
            Expanded(child: Center(child: pushButton)),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'wrapping a Scaffold (not the reverse) neither overflows nor crashes '
    'the close button for lack of a Material ancestor',
    (tester) async {
      await tester.pumpWidget(
        _hostWrappingScaffold(
          _Pusher(notification: AppNotification.error('Connection failed')),
        ),
      );

      await tester.tap(find.text('push'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
      expect(find.text('Connection failed'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Connection failed'), findsNothing);
    },
  );

  testWidgets('pushAlert renders the message', (tester) async {
    await tester.pumpWidget(
      _host(
        _Pusher(notification: AppNotification.info('Context acknowledged')),
      ),
    );

    await tester.tap(find.text('push'));
    await tester.pump(); // start the entry animation
    await tester.pump(const Duration(milliseconds: 250)); // let it finish

    expect(find.text('Context acknowledged'), findsOneWidget);
  });

  testWidgets('auto-dismisses after its duration', (tester) async {
    await tester.pumpWidget(
      _host(
        _Pusher(
          notification: AppNotification.warning(
            'Microphone permission denied',
            duration: const Duration(seconds: 2),
          ),
        ),
      ),
    );

    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Microphone permission denied'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('Microphone permission denied'), findsNothing);
  });

  testWidgets('the close button dismisses it immediately', (tester) async {
    await tester.pumpWidget(
      _host(_Pusher(notification: AppNotification.error('Failed to send: x'))),
    );

    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Failed to send: x'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(find.text('Failed to send: x'), findsNothing);
  });

  testWidgets('stacks multiple toasts at the same position', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            _Pusher(notification: AppNotification.info('First')),
            _Pusher(notification: AppNotification.success('Second')),
          ],
        ),
      ),
    );

    for (final button in tester.widgetList<ElevatedButton>(
      find.byType(ElevatedButton),
    )) {
      await tester.tap(find.byWidget(button));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('evicts the oldest toast past maxNotifications', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationHost(
            maxNotifications: 1,
            child: Column(
              children: [
                _Pusher(
                  notification: AppNotification(
                    message: 'Oldest',
                    severity: NotificationSeverity.info,
                    position: NotificationPosition.topCenter,
                  ),
                ),
                _Pusher(
                  notification: AppNotification(
                    message: 'Newest',
                    severity: NotificationSeverity.info,
                    position: NotificationPosition.topCenter,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final button in tester.widgetList<ElevatedButton>(
      find.byType(ElevatedButton),
    )) {
      await tester.tap(find.byWidget(button));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Oldest'), findsNothing);
    expect(find.text('Newest'), findsOneWidget);
  });
}
