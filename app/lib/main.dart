import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';
import 'features/auth/data/supabase_auth_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabasePublishableKey);
  runApp(
    ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(Supabase.instance.client),
      ],
      child: const PharmacyApp(),
    ),
  );
}