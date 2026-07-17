// ignore_for_file: unused_element, unused_import

import 'package:flutter/material.dart';
import 'package:webs/api/api_client.dart';
// import 'package:webs/auth/auth_screen.dart';
import 'package:webs/lab/table_demo_screen.dart';
import 'package:webs/live_chat/live_chat_screen.dart';
import 'package:webs/live_chat/models.dart';
import 'package:webs/ui/core/app_theme.dart';
import 'package:webs/ui/core/theme_controller.dart';

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Live Chat',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const LiveChat(chatContext: _demoChatContext),

          // home: TableDemoScreen(),
        );
      },
    );
  }
}
