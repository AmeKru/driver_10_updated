import 'dart:async'; // To use Timer

import 'package:driver_10_updated/pages/bus_data.dart';
import 'package:driver_10_updated/pages/loading.dart';
import 'package:driver_10_updated/pages/map_page.dart';
import 'package:driver_10_updated/pages/morning.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BusInfo().loadData();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static int screenTime_hour = 13; // 13/1PM 15/3PM to afternoon service
  static int screenTime_min = 00;

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
    print('Checking time');
    setState(() {
      DateTime now = DateTime.now();

      print('hour: ${now.hour} minute: ${now.minute}');
      _currentRoute =
          (now.hour >= MyApp.screenTime_hour &&
              now.minute >= MyApp.screenTime_min)
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
        '/home': (context) => MapPage(),
        '/morning': (context) => MorningPage(),
      },
    );
  }
}
