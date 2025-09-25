import 'dart:async'; // To use Timer

import 'package:driver_10_updated/global.dart';
import 'package:driver_10_updated/pages/afternoon_page.dart';
import 'package:driver_10_updated/pages/morning_page.dart';
import 'package:driver_10_updated/utils/bus_data.dart';
import 'package:driver_10_updated/utils/loading.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BusInfo().loadData();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  late Timer _timer;
  String _currentRoute = '/'; // Default route
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkTime();

    // Set a timer that runs every minute
    _timer = Timer.periodic(Duration(seconds: 10), (timer) {
      _checkTime();
    });
  }

  // Function to check the current time and update the route
  void _checkTime() {
    if (kDebugMode) {
      print('Checking time');
    }
    setState(() {
      DateTime now = DateTime.now();

      if (kDebugMode) {
        print('hour: ${now.hour} minute: ${now.minute}');
      }
      _currentRoute =
          (now.hour >= screenTimeHour && now.minute >= screenTimeMin)
          ? '/home'
          : '/morning';
    });
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: _currentRoute, // Use the dynamic route
      routes: {
        '/': (context) => Loading(),
        '/home': (context) => AfternoonPage(),
        '/morning': (context) => MorningPage(),
      },
    );
  }
}
