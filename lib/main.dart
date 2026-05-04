import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:webs/app.dart';
import 'package:webs/auth/token_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TokenService.loadSavedToken();
  usePathUrlStrategy();
  runApp(const App());
}
