import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/app_bootstrap.dart';

Future<void> main() async {
  final app = await bootstrapApp(child: const SafeWalletApp());
  runApp(app);
}
