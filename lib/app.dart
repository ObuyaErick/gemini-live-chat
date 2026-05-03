// ignore_for_file: unused_element, unused_import

import 'package:flutter/material.dart';
import 'package:webs/lab/table_demo_screen.dart';
import 'package:webs/live_chat/live_chat_screen.dart';
import 'package:webs/live_chat/models.dart';

const _demoChatContext = ChatContext(
  module: 'analytics',
  page: 'pdp_overview',
  path: '/analytics/pdp/overview',
  title: 'PDP Overview',
  params: <String, dynamic>{
    'date_range': 'last_30_days',
    'category_id': 'apparel',
  },
  // selection: ChatContextSelection(
  //   type: 'product',
  //   id: 'prod_123',
  //   label: 'Blue Running Shoes',
  // ),
);

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const LiveChat(chatContext: _demoChatContext),
      // home: TableDemoScreen(),
    );
  }
}
