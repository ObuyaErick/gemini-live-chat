import 'package:flutter_test/flutter_test.dart';
import 'package:webs/live_chat/providers/live_chat_provider.dart';

import 'live_chat_fakes.dart';

/// Covers the server's documented deviation from the staged accept/reject
/// design (consumer guide §5.4, "Text document retrieve and edit lifecycle"):
/// agent edits arrive via `text_diff` already committed server-side, with a
/// `to_version` assigned. The client must apply them immediately — never
/// stage them as a proposal, and never echo them back as a `document_edit`
/// (that double-applies and forces a `document_resync`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatSocket socket;
  late LiveChatProvider provider;

  setUp(() async {
    socket = FakeChatSocket();
    provider = LiveChatProvider(
      socket: socket,
      audioPlayer: SilentAudioPlayer(),
      micStreamer: FakeMicStreamer(),
    );
    await provider.connect();

    // document_resync is the simplest way to seed an open document in a test
    // — it hands over the full body directly, no attachment URL fetch needed.
    socket.emit({
      'type': 'document_resync',
      'content': {
        'file_id': 'doc1',
        'version': 1,
        'filename': 'quarterly-review.md',
        'mime_type': 'text/markdown',
        'text': 'line one\nline two',
      },
    });
  });

  tearDown(() => provider.dispose());

  Map<String, dynamic> textDiff({
    required int fromVersion,
    required int toVersion,
    required String oldValue,
    required String newValue,
  }) => {
    'type': 'text_diff',
    'content': {
      'file_id': 'doc1',
      'from_version': fromVersion,
      'to_version': toVersion,
      'origin': 'agent',
      'diff': 'diff --git a/quarterly-review.md b/quarterly-review.md',
      'old_value': oldValue,
      'new_value': newValue,
    },
  };

  test('an agent edit is applied immediately, not staged', () {
    socket.emit(
      textDiff(
        fromVersion: 1,
        toVersion: 2,
        oldValue: 'line one\nline two',
        newValue: 'line one\nCHANGED',
      ),
    );

    final doc = provider.openDocuments['doc1']!;
    expect(doc.content, 'line one\nCHANGED');
    expect(doc.version, 2);
    // Nothing is echoed back — the server already committed the change.
    expect(socket.sent, isEmpty);
  });

  test('accepting the undo banner just clears it — no frame sent', () {
    socket.emit(
      textDiff(
        fromVersion: 1,
        toVersion: 2,
        oldValue: 'line one\nline two',
        newValue: 'line one\nCHANGED',
      ),
    );
    expect(provider.pendingProposals, contains('doc1'));

    provider.acceptProposal('doc1');

    expect(provider.pendingProposals, isNot(contains('doc1')));
    expect(socket.sent, isEmpty);
    // The already-applied edit stands.
    expect(provider.openDocuments['doc1']!.content, 'line one\nCHANGED');
  });

  test('rejecting restores old_value and relays it as a manual edit', () {
    socket.emit(
      textDiff(
        fromVersion: 1,
        toVersion: 2,
        oldValue: 'line one\nline two',
        newValue: 'line one\nCHANGED',
      ),
    );

    provider.rejectProposal('doc1');

    final doc = provider.openDocuments['doc1']!;
    expect(doc.content, 'line one\nline two');
    // Restoring is a manual edit: the client advances its own version,
    // the server sends no reply on a successful document_edit (guide §5.4).
    expect(doc.version, 3);
    expect(provider.pendingProposals, isNot(contains('doc1')));

    expect(socket.sent, hasLength(1));
    final sent = socket.sent.single;
    expect(sent['type'], 'document_edit');
    expect(sent['content']['file_id'], 'doc1');
    expect(sent['content']['origin'], 'user');
  });
}
