import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FMTCObjectBoxBackend().initialise();
  final tileStore = FMTCStore('collecteCache');
  await tileStore.manage.create();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: CollecteApp()));
}
