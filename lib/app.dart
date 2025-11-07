import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'features/itinerary/application/collector_track_recorder.dart';
import 'routing/app_router.dart';

class CollecteApp extends ConsumerWidget {
  const CollecteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(collectorTrackRecorderProvider);

    return MaterialApp.router(
      title: 'Collecte Revendeurs',
      routerConfig: router,
      theme: buildAppTheme(GoogleFonts.poppinsTextTheme()),
      debugShowCheckedModeBanner: false,
    );
  }
}
