# webs

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

```python
_GENERATE_CHARTS_RESULT_INSTRUCTIONS = (
    "The `generate_charts` result has shape "
    "{stdout, stderr, exit_code, charts: [{filename, mime_type, url}, ...]}.\n"
    "Each `url` is an opaque attachment placeholder of the form "
    "`attachment://<file_id>`. It is NOT a broken link — the server rewrites "
    "it to a real, fetchable URL before the message reaches the user. Embed "
    "the placeholder verbatim; do not modify it, shorten it, prepend a host, "
    "or comment on its format.\n"
    "If `exit_code` is 0 and `charts` is non-empty, embed every chart inline "
    "in your reply using Markdown image syntax: `![<filename>](<url>)`, using "
    "the exact `url` and `filename` from each entry. Place each image where it "
    "best supports the surrounding analysis, and reference it in prose (e.g. "
    "\"as the chart below shows…\"). Never paste the URL as plain text and "
    "never describe the chart as \"attached\" or \"saved\" — the user only "
    "sees what is rendered in the message body.\n"
    "If `exit_code` is non-zero, `charts` is empty, or `stderr` indicates a "
    "failure, do NOT emit any image markdown. Instead, briefly explain what "
    "went wrong based on `stderr` and propose a corrected next step."
)
```

<!--  -->

The current `generate_charts` tool appended at src/agent/data_crew.py uses targets matplotlib but these charts are not interative.

There is a concern that we introduce a new tool that produces chat in plotly format condering they can be parsed by different frameworks and visualized with the intreractiveness like zooming etc.

Please help plan this feature to exist alongside matplotlib chart generation

<!--  -->

plotly tool result instructions should be something else away from `![<filename>](<url>)`

Considering plotly should be handled by callers (webscoket client and they are being injected as attachments besides content). We need a better way of telling the model how do do it's final response. But they should not be embedded using `attachment://<file_id>`, this should be left for the retired matplotlib tool. I just need you to craft \_GENERATE_CHARTS_RESULT_INSTRUCTIONS so that the model crafts a more friendly user facing messaging then rendering protly data to be entirely left for the calling end like assuming its flutter web client, they basically read it from attachemnts if it exists and renders them as they wish.

When resuming a session, the data loaded from bigquery should also resolve the message attachment refs the same way the \_finalize method does using \_attachments_for_wire including endpoints that load threads

<!--  -->

```dart
static String token =
      // 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJsZW5ub3hAcmVkdXplci50ZWNoIiwiYWNjb3VudCI6ImxlaG5lcl92ZXJzYW5kIiwiaWF0IjoxNTE2MjM5MDIyfQ.PO36Gmas2xAgQNWwOyHHfCnux48uf6DWhU2GHxltYjU';
  'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJlcmlja0ByZWR1emVyLnRlY2giLCJzY29wZSI6ImFkbWluIiwicHJvamVjdCI6Indpbi1wLW1vYmlsZXVuaXZlcnNlIiwiYWNjb3VudCI6Im1vYmlsZV91bml2ZXJzZV9hcGkiLCJkcml2ZUlkIjoiMEFQSnJac1JFbWxPOVVrOVBWQSIsImlzcyI6Im9yZ2FuaXphdGlvbkBib3hhbGluby5jb20iLCJqdGkiOiI1MTRjMTQ1YzdhN2RmZTE1Zjg3ZDgzZDhmMDM3YWE2MWE4NDllMTA3IiwiZXhwIjoxNzc3MzEyODY1LCJjcmVhdGVkIjoiMjAyNi0wNC0yNyAwODowMToxMCJ9.i3PYfIhZIyDM8wBTDjuoTqwjtR24Xdc5ElnCaOFqtw8';
```
