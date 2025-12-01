//import 'dart:async'; // To use Timer
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
// Amplify imports
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pages/main_page.dart';
import '../utils/get_data.dart';
import '../utils/text_sizing.dart';
import 'amplifyconfiguration.dart';
import 'models/ModelProvider.dart';

////////////////////////////////////////////////////////////////////////////////
// Top-level Amplify configuration helper and readiness future
Future<void> configureAmplifyOnce() async {
  try {
    if (!Amplify.isConfigured) {
      final provider = ModelProvider();

      // Add DataStore
      Amplify.addPlugin(AmplifyDataStore(modelProvider: provider));

      // Add API (AppSync)
      Amplify.addPlugin(
        AmplifyAPI(options: APIPluginOptions(modelProvider: provider)),
      );

      // Add Auth (Cognito User Pool + Identity Pool)
      Amplify.addPlugin(AmplifyAuthCognito());

      // Configure Amplify with amplifyconfiguration.dart
      await Amplify.configure(amplifyconfig);

      if (kDebugMode) print('Amplify configured');
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (kDebugMode) {
        print('Identity ID: ${session.identityIdResult.value}');
        print('Access Key: ${session.credentialsResult.value.accessKeyId}');
      }
    } else {
      if (kDebugMode) print('Amplify already configured');
    }
  } catch (e, st) {
    if (kDebugMode) print('Amplify configuration error: $e\n$st');
    rethrow;
  }
}

////////////////////////////////////////////////////////////////////////////////
// Exposed readiness future other code can await

final Future<void> amplifyReady = configureAmplifyOnce();

////////////////////////////////////////////////////////////////////////////////
// main function

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure Amplify configured before the app starts
  try {
    await amplifyReady;
  } catch (e) {
    if (kDebugMode) print('Amplify failed to configure in main: $e');
  }

  // load other app data
  await BusData().loadData();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(MyApp());
}

////////////////////////////////////////////////////////////////////////////////
// MyApp

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('rebuilt app');
    }
    // sets size at start so layout will scale accordingly
    TextSizing.setSize(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/home',
      routes: {'/home': (context) => MainPage()},
    );
  }
}
