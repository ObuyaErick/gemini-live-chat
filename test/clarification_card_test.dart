import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webs/live_chat/models/clarification.dart';
import 'package:webs/live_chat/widgets/clarification_card.dart';

/// The clarification card's answer assembly: picked labels and the per-question
/// "Other" free text ride the same positional `answers` lists (the server
/// partitions them by label match), and single-select means one answer total —
/// a label OR the user's own words, never both.

PendingClarification _clarification({bool multiSelect = false}) =>
    PendingClarification(
      toolName: 'ASK_USER',
      questions: [
        ClarificationQuestion(
          question: 'Which theme?',
          options: const [
            ClarificationOption(label: 'wi'),
            ClarificationOption(label: 'Dark'),
          ],
          multiSelect: multiSelect,
        ),
      ],
    );

Widget _host(PendingClarification clarification,
        void Function(List<List<String>>) onSubmit) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ClarificationCard(
            clarification: clarification,
            onSubmit: onSubmit,
          ),
        ),
      ),
    );

void main() {
  testWidgets('picked label is submitted as the answer', (tester) async {
    List<List<String>>? submitted;
    await tester.pumpWidget(_host(_clarification(), (a) => submitted = a));

    await tester.tap(find.text('Dark'));
    await tester.pump();
    await tester.tap(find.text('Submit answers'));

    expect(submitted, [
      ['Dark'],
    ]);
  });

  testWidgets('Other free text is submitted verbatim', (tester) async {
    List<List<String>>? submitted;
    await tester.pumpWidget(_host(_clarification(), (a) => submitted = a));

    await tester.tap(find.text('Other…'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField),
      '  something colourful — launch deck vibes  ',
    );
    await tester.tap(find.text('Submit answers'));

    // Trimmed here; the server tells it apart from labels.
    expect(submitted, [
      ['something colourful — launch deck vibes'],
    ]);
  });

  testWidgets('single-select: typing supersedes a picked label', (tester) async {
    List<List<String>>? submitted;
    await tester.pumpWidget(_host(_clarification(), (a) => submitted = a));

    await tester.tap(find.text('Dark'));
    await tester.pump();
    await tester.tap(find.text('Other…'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'neither of these');
    await tester.tap(find.text('Submit answers'));

    expect(submitted, [
      ['neither of these'],
    ]);
  });

  testWidgets('single-select: picking a label supersedes typed text',
      (tester) async {
    List<List<String>>? submitted;
    await tester.pumpWidget(_host(_clarification(), (a) => submitted = a));

    await tester.tap(find.text('Other…'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'never mind');
    await tester.tap(find.text('Dark'));
    await tester.pump();
    await tester.tap(find.text('Submit answers'));

    expect(submitted, [
      ['Dark'],
    ]);
  });

  testWidgets('multi-select mixes checked labels with the user own answer',
      (tester) async {
    List<List<String>>? submitted;
    await tester.pumpWidget(
      _host(_clarification(multiSelect: true), (a) => submitted = a),
    );

    await tester.tap(find.text('wi'));
    await tester.pump();
    await tester.tap(find.text('Add my own answer…'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'also try the neon one');
    await tester.tap(find.text('Submit answers'));

    expect(submitted, [
      ['wi', 'also try the neon one'],
    ]);
  });

  testWidgets('nothing chosen submits a dismissal', (tester) async {
    List<List<String>>? submitted;
    await tester.pumpWidget(_host(_clarification(), (a) => submitted = a));

    await tester.tap(find.text('Submit answers'));

    expect(submitted, [<String>[]]);
  });
}
