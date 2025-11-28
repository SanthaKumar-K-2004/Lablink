import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/flavors.dart';
import 'presentation/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize production flavor
  FlavorConfig.setInstance(FlavorConfig.prod());

  runApp(
    const ProviderScope(
      child: LabLinkApp(),
    ),
  );
}
