import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

class BusInfo {
  static final BusInfo _instance = BusInfo._internal();
  factory BusInfo() => _instance;
  BusInfo._internal();

  final List<DateTime> arrivalTimeKAP = [];
  final List<DateTime> arrivalTimeCLE = [];
  final List<DateTime> departureTimeKAP = [];
  final List<DateTime> departureTimeCLE = [];
  final List<String> busStop = [];
  bool isDataLoaded = false;

  Future<void> busData() async {
    try {
      Response response = await get(
        Uri.parse(
          'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/busstop?info=BusStops',
        ),
      );
      dynamic data = jsonDecode(response.body);

      List<dynamic> positions = data['positions'];
      for (var position in positions) {
        String id = position['id'];
        busStop.add(id);
        if (kDebugMode) {
          print(id);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('caught error: $e');
      }
    }
  }

  Future<void> arrivalTimesKAP() async {
    try {
      http.Response response = await http.get(
        Uri.parse(
          'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=KAP_MorningBus',
        ),
      );
      dynamic data = jsonDecode(response.body);

      List<dynamic> times = data['times'];
      for (var time in times) {
        String timeStr = time['time'];
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        arrivalTimeKAP.add(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            hour,
            minute,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('caught error: $e');
      }
    }
  }

  Future<void> arrivalTimesCLE() async {
    try {
      http.Response response = await http.get(
        Uri.parse(
          'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=CLE_MorningBus',
        ),
      );
      dynamic data = jsonDecode(response.body);

      List<dynamic> times = data['times'];
      for (var time in times) {
        String timeStr = time['time'];
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        arrivalTimeCLE.add(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            hour,
            minute,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('caught error: $e');
      }
    }
  }

  Future<void> departureTimesKAP() async {
    try {
      http.Response response = await http.get(
        Uri.parse(
          'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=KAP_AfternoonBus',
        ),
      );
      dynamic data = jsonDecode(response.body);

      List<dynamic> times = data['times'];
      for (var time in times) {
        String timeStr = time['time'];
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        departureTimeKAP.add(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            hour,
            minute,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('caught error: $e');
      }
    }
  }

  Future<void> dtCLE() async {
    try {
      http.Response response = await http.get(
        Uri.parse(
          'https://6f11dyznc2.execute-api.ap-southeast-2.amazonaws.com/prod/timing?info=CLE_AfternoonBus',
        ),
      );
      dynamic data = jsonDecode(response.body);

      List<dynamic> times = data['times'];
      for (var time in times) {
        String timeStr = time['time'];
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        departureTimeCLE.add(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            hour,
            minute,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('caught error: $e');
      }
    }
  }

  Future<void> loadData() async {
    if (!isDataLoaded) {
      await arrivalTimesKAP();
      await arrivalTimesCLE();
      await departureTimesKAP();
      await dtCLE();
      await busData();
      isDataLoaded = true;
    }
  }
}
