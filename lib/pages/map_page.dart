import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:driver_10_updated/amplifyconfiguration.dart';
import 'package:driver_10_updated/models/model_provider.dart';
import 'package:driver_10_updated/pages/bus_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:uuid/uuid.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  final ScrollController controller = ScrollController();
  final BusInfo _busInfo = BusInfo();
  String? selectedMRT;
  int? selectedTripNo;
  String? selectedBusStop;
  int busStopIndex = 8;
  final int tripNoCLE = 4;
  final int tripNoKAP = 13;
  String? bookingID;
  List<String> busStops = [];
  int? trackBooking;
  late Timer _timer;
  Timer? _clockTimer;
  int? totalBooking;
  bool loadingTotalCount = true;
  bool loadingCount = true;
  int fullCapacity = 30;
  List<DateTime> arrivalTimeKAP = [];
  List<DateTime> arrivalTimeCLE = [];
  DateTime now = DateTime.now();
  Duration timeUpdateInterval = Duration(seconds: 1);
  Duration apiFetchInterval = Duration(minutes: 1);
  int secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    busStops = _busInfo.busStop;
    busStops = busStops.sublist(2); //sublist used to start from index 2
    selectedBusStop = busStops[busStopIndex];
    arrivalTimeKAP = _busInfo.departureTimeKAP;
    arrivalTimeCLE = _busInfo.departureTimeCLE;
    _configureAmplify();

    _timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      _updateTotalBooking();
      _updateBooking();
    });

    getTime().then((_) {
      _clockTimer = Timer.periodic(timeUpdateInterval, (timer) {
        updateTimeManually();
        secondsElapsed += timeUpdateInterval.inSeconds;

        if (secondsElapsed >= apiFetchInterval.inSeconds) {
          getTime();
          secondsElapsed = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The app is resumed; re-fetch the time from the API
      getTime();
    }
  }

  void showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        //callback function that returns a widget
        return AlertDialog(
          title: Text('Alert'),
          content: Text('Please select MRT, BusStop, and TripNo.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void fullAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Alert'),
          content: Text('Booking Full'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showVoidDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Alert'),
          content: Text('No Booking to delete'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _updateBooking() async {
    if (selectedTripNo != null &&
        selectedBusStop != null &&
        selectedMRT != null) {
      if (selectedMRT == 'CLE') {
        trackBooking =
            await getCountCLE(selectedTripNo!, selectedBusStop!) ?? 0;
      } else {
        trackBooking =
            await getCountKAP(selectedTripNo!, selectedBusStop!) ?? 0;
      }
      setState(() {
        trackBooking = trackBooking;
        loadingCount = false;
      });
    }
  }

  void _updateTotalBooking() async {
    if (selectedMRT != null && selectedTripNo != null) {
      totalBooking = await countBooking(selectedMRT!, selectedTripNo!);
    }
    setState(() {
      totalBooking = totalBooking;
      loadingTotalCount = false;
    });
  }

  void _configureAmplify() async {
    final provider = ModelProvider();
    final amplifyApi = AmplifyAPI(
      options: APIPluginOptions(modelProvider: provider),
    );
    final dataStorePlugin = AmplifyDataStore(modelProvider: provider);

    Amplify.addPlugin(dataStorePlugin);
    Amplify.addPlugin(amplifyApi);
    Amplify.configure(amplifyconfig);

    if (kDebugMode) {
      print('Amplify configured');
    }
  }

  Future<void> create(String mrtStation, int tripNo, String busStop) async {
    try {
      final model = BOOKINGDETAILS5(
        id: Uuid().v4(),
        MRTStation: mrtStation,
        TripNo: tripNo,
        BusStop: busStop,
      );

      final request = ModelMutations.create(model);
      final response = await Amplify.API.mutate(request: request).response;

      final createdBOOKINGDETAILS5 = response.data;
      if (createdBOOKINGDETAILS5 == null) {
        safePrint('errors: ${response.errors}');
        return;
      }

      String id = createdBOOKINGDETAILS5.id;
      setState(() {
        bookingID = id;
      });
      safePrint('Mutation result: $bookingID');

      // Ensure count update happens only after the booking creation is confirmed
      if (mrtStation == 'KAP') {
        await countKAP(tripNo, busStop);
      } else {
        await countCLE(tripNo, busStop);
      }
    } on ApiException catch (e) {
      safePrint('Mutation failed: $e');
    }
  }

  Future<BOOKINGDETAILS5?> readByID() async {
    final request = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.ID.eq(bookingID),
    );
    final response = await Amplify.API.query(request: request).response;
    final data = response.data?.items.firstOrNull;
    return data;
  }

  Future<BOOKINGDETAILS5?> searchInstance(
    String mrt,
    int tripNo,
    String busStop,
  ) async {
    final request = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: (BOOKINGDETAILS5.MRTSTATION
          .eq(mrt)
          .and(
            BOOKINGDETAILS5.TRIPNO
                .eq(tripNo)
                .and(BOOKINGDETAILS5.BUSSTOP.eq(busStop)),
          )),
    );
    final response = await Amplify.API.query(request: request).response;
    final data = response.data?.items.firstOrNull;
    return data;
  }

  Future<int?> countBooking(String mrt, int tripNo) async {
    int? count;
    try {
      final request = ModelQueries.list(
        BOOKINGDETAILS5.classType,
        where: BOOKINGDETAILS5.MRTSTATION
            .eq(mrt)
            .and(BOOKINGDETAILS5.TRIPNO.eq(tripNo)),
      );
      final response = await Amplify.API.query(request: request).response;
      final data = response.data?.items;

      if (data != null) {
        count = data.length;
        if (kDebugMode) {
          print('$count');
        }
      } else {
        count = 0;
      }
    } catch (e) {
      if (kDebugMode) {
        print('$e');
      }
    }
    return count;
  }

  Future<void> minus(String mrt, int tripNo, String busStop) async {
    final BOOKINGDETAILS5? bookingToDelete = await searchInstance(
      mrt,
      tripNo,
      busStop,
    );
    if (bookingToDelete != null) {
      final request = ModelMutations.delete(bookingToDelete);
      final response = await Amplify.API.mutate(request: request).response;

      if (bookingToDelete.MRTStation == 'KAP') {
        countKAP(bookingToDelete.TripNo, bookingToDelete.BusStop);
      } else {
        countCLE(bookingToDelete.TripNo, bookingToDelete.BusStop);
      }
    } else {
      if (kDebugMode) {
        print('No booking deleted');
      }
    }
  }

  Future<int?> getCountCLE(int tripNo, String busStop) async {
    int? count;
    try {
      final request = ModelQueries.list(
        BOOKINGDETAILS5.classType,
        where: BOOKINGDETAILS5.MRTSTATION
            .eq('CLE')
            .and(
              BOOKINGDETAILS5.TRIPNO
                  .eq(tripNo)
                  .and(BOOKINGDETAILS5.BUSSTOP.eq(busStop)),
            ),
      );
      final response = await Amplify.API.query(request: request).response;
      final data = response.data?.items;

      if (data != null) {
        count = data.length;
        if (kDebugMode) {
          print('$count');
        }
      } else {
        count = 0;
      }
    } catch (e) {
      if (kDebugMode) {
        print('$e');
      }
    }
    return count;
  }

  Future<int?> countCLE(int tripNo, String busStop) async {
    int? count;
    // Read if there is a row
    final request1 = ModelQueries.list(
      CLEAfternoon.classType,
      where: CLEAfternoon.TRIPNO
          .eq(tripNo)
          .and(CLEAfternoon.BUSSTOP.eq(busStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    if (kDebugMode) {
      print('Row found');
    }

    // If data1 != null, delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      final response2 = await Amplify.API.mutate(request: request2).response;
    }

    // Count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION
          .eq('CLE')
          .and(BOOKINGDETAILS5.TRIPNO.eq(tripNo))
          .and(BOOKINGDETAILS5.BUSSTOP.eq(busStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    if (data2 != null) {
      count = data2.length;
      if (kDebugMode) {
        print('$count');
      }
    } else {
      count = 0;
    }

    // If count is greater than 0, create the row
    if (count > 0) {
      final model = CLEAfternoon(
        BusStop: busStop,
        TripNo: tripNo,
        Count: count,
      );
      final request4 = ModelMutations.create(model);
      final response4 = await Amplify.API.mutate(request: request4).response;
      final createdCLE = response4.data;
    }

    return count;
  }

  Future<int?> getCountKAP(int tripNo, String busStop) async {
    int? count;
    try {
      final request = ModelQueries.list(
        BOOKINGDETAILS5.classType,
        where: BOOKINGDETAILS5.MRTSTATION
            .eq('KAP')
            .and(
              BOOKINGDETAILS5.TRIPNO
                  .eq(tripNo)
                  .and(BOOKINGDETAILS5.BUSSTOP.eq(busStop)),
            ),
      );
      final response = await Amplify.API.query(request: request).response;
      final data = response.data?.items;

      if (data != null) {
        count = data.length;
        if (kDebugMode) {
          print('$count');
        }
      } else {
        count = 0;
      }
    } catch (e) {
      if (kDebugMode) {
        print('$e');
      }
    }
    return count;
  }

  Future<int?> countKAP(int tripNo, String busStop) async {
    int? count;
    // Read if there is a row
    final request1 = ModelQueries.list(
      KAPAfternoon.classType,
      where: KAPAfternoon.TRIPNO
          .eq(tripNo)
          .and(KAPAfternoon.BUSSTOP.eq(busStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    if (kDebugMode) {
      print('Row found');
    }

    // If data1 != null, delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      final response2 = await Amplify.API.mutate(request: request2).response;
    }

    // Count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION
          .eq('KAP')
          .and(BOOKINGDETAILS5.TRIPNO.eq(tripNo))
          .and(BOOKINGDETAILS5.BUSSTOP.eq(busStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    if (data2 != null) {
      count = data2.length;
      if (kDebugMode) {
        print('$count');
      }
    } else {
      count = 0;
    }
    // If count is greater than 0, create the row
    if (count > 0) {
      final model = KAPAfternoon(
        BusStop: busStop,
        TripNo: tripNo,
        Count: count,
      );
      final request4 = ModelMutations.create(model);
      final response4 = await Amplify.API.mutate(request: request4).response;
      final createdKAP = response4.data;
    }
    if (kDebugMode) {
      print("Returning KAP count");

      print("$count");
    }
    return count;
  }

  List<DropdownMenuItem<int>> _buildTripNoItems(int tripNo) {
    return List<DropdownMenuItem<int>>.generate(
      tripNo,
      (int index) => DropdownMenuItem<int>(
        value: index + 1,
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.06,
            fontWeight: FontWeight.w300,
            fontFamily: 'NewAmsterdam',
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildBusStopItems() {
    return busStops.map((String busStop) {
      return DropdownMenuItem<String>(
        value: busStop,
        child: Text(
          busStop,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.06,
            fontWeight: FontWeight.w300,
            fontFamily: 'NewAmsterdam',
          ),
        ),
      );
    }).toList();
  }

  List<DateTime> getDepartureTimes() {
    if (selectedMRT == 'KAP') {
      return _busInfo.departureTimeKAP;
    } else {
      return _busInfo.departureTimeCLE;
    }
  }

  Future<void> getTime() async {
    try {
      final uri = Uri.parse(
        'https://www.timeapi.io/api/time/current/zone?timeZone=ASIA%2FSINGAPORE',
      );
      // final uri = Uri.parse('https://worldtimeapi.org/api/timezone/Singapore');
      if (kDebugMode) {
        print("Printing URI");
        print(uri);
      }
      final response = await get(uri);
      if (kDebugMode) {
        print("Printing response");

        print(response);
      }
      // Response response = await get(
      //     Uri.parse('https://worldtimeapi.org/api/timezone/Singapore'));
      if (kDebugMode) {
        print(response.body);
      }
      Map data = jsonDecode(response.body);
      if (kDebugMode) {
        print(data);
      }
      String datetime =
          data['dateTime']; //timeapi.io uses dateTime not datetime
      //String offset = data['utc_offset'].substring(1, 3);

      setState(() {
        now = DateTime.parse(datetime);
        //now = now.add(Duration(hours: int.parse(offset)));
        if (kDebugMode) {
          print('Printing Time: $now');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('caught error: $e');
      }
    }
  }

  void updateTimeManually() {
    if (mounted) {
      setState(() {
        now = now.add(timeUpdateInterval);
      });
    }
  }

  Color? generateColor(List<DateTime> dt, int selectedTripNo) {
    List<Color?> colors = [
      Colors.red[100],
      Colors.yellow[200],
      Colors.white,
      Colors.tealAccent[100],
      Colors.orangeAccent[200],
      Colors.greenAccent[100],
      Colors.indigo[100],
      Colors.purpleAccent[100],
      Colors.grey[400],
      Colors.limeAccent[100],
    ];

    DateTime departureTime = dt[selectedTripNo - 1];
    int departureSeconds =
        departureTime.hour * 3600 + departureTime.minute * 60;
    int combinedSeconds = now.second + departureSeconds;
    int roundedSeconds = (combinedSeconds ~/ 10) * 10;
    DateTime roundedTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      roundedSeconds,
    );
    int seed = roundedTime.millisecondsSinceEpoch ~/ (1000 * 10);
    Random random = Random(seed);
    int syncedRandomNum = random.nextInt(10);
    return colors[syncedRandomNum];
  }

  Widget drawLine() {
    return Column(
      // Use Row here
      children: [
        drawWidth(0.025),
        Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: 2,
          color: Colors.black,
        ),
      ],
    );
  }

  Widget addTitle(String title, double fontSize) {
    return Align(
      alignment: Alignment.center,
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'Timmana',
        ),
      ),
    );
  }

  Widget drawWidth(double size) {
    return SizedBox(width: MediaQuery.of(context).size.width * size);
  }

  Widget drawHeight(double size) {
    return SizedBox(width: MediaQuery.of(context).size.height * size);
  }

  String formatTime(DateTime time) {
    String hour = time.hour.toString().padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String formatTimesecond(DateTime time) {
    String hour = time.hour.toString().padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');
    String sec = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$sec';
  }

  Widget normalText(String text, double sizeOfFont) {
    return Text(
      text,
      style: TextStyle(
        fontSize: sizeOfFont,
        fontWeight: FontWeight.w300,
        fontFamily: 'NewAmsterdam',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print("TrackBooking & TotalBooking");
      print("$trackBooking");

      print("$totalBooking");
    }
    return Scaffold(
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Container(
              color: (selectedTripNo != null)
                  ? generateColor(getDepartureTimes(), selectedTripNo!)
                  : Colors.lightBlue[100],
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  addTitle(
                    'MooBus Safety Operator',
                    MediaQuery.of(context).size.width * 0.1,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      addTitle(
                        'Tracking',
                        MediaQuery.of(context).size.width * 0.1,
                      ),
                      Text(
                        '(Afternoon)',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.08,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          fontFamily: 'Timmana',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  drawLine(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  addTitle(
                    'Selected Route',
                    MediaQuery.of(context).size.width * 0.08,
                  ),
                  Row(
                    children: [
                      drawWidth(0.2),
                      normalText(
                        'CAMPUS   --   ',
                        MediaQuery.of(context).size.width * 0.07,
                      ),
                      SizedBox(
                        width: 150, // Fixed width for consistency
                        child: DropdownButton<String>(
                          value: selectedMRT,
                          items: ['CLE', 'KAP'].map<DropdownMenuItem<String>>((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.06,
                                  fontWeight: FontWeight.w300,
                                  fontFamily: 'NewAmsterdam',
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedMRT = newValue;
                              selectedTripNo =
                                  null; // Reset selected trip no when MRT station changes
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  drawLine(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Row(
                    children: [
                      drawWidth(0.1),
                      normalText(
                        'TRIP NUMBER',
                        MediaQuery.of(context).size.width * 0.07,
                      ),
                      drawWidth(0.1),
                      normalText(
                        'DEPARTURE TIME',
                        MediaQuery.of(context).size.width * 0.07,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      drawWidth(0.25),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.2,
                        height:
                            MediaQuery.of(context).size.height *
                            0.05, // Fixed width for consistency
                        child: DropdownButton<int>(
                          value: selectedTripNo,
                          items: selectedMRT == 'CLE'
                              ? _buildTripNoItems(
                                  _busInfo.departureTimeCLE.length,
                                )
                              : selectedMRT == 'KAP'
                              ? _buildTripNoItems(
                                  _busInfo.departureTimeKAP.length,
                                )
                              : [],
                          onChanged: (int? newValue) {
                            setState(() {
                              selectedTripNo = newValue;
                            });
                          },
                        ),
                      ),
                      drawWidth(0.1),
                      if (selectedMRT != null && selectedTripNo != null)
                        Text(
                          selectedMRT == 'CLE'
                              ? formatTime(arrivalTimeCLE[selectedTripNo! - 1])
                              : formatTime(arrivalTimeKAP[selectedTripNo! - 1]),
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.06,
                            fontWeight: FontWeight.w300,
                            fontFamily: 'NewAmsterdam',
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  drawLine(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Column(
                    children: [
                      addTitle(
                        'Arriving Bus Stop Info',
                        MediaQuery.of(context).size.width * 0.08,
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                      normalText(
                        'Bus Stop:   ',
                        MediaQuery.of(context).size.width * 0.07,
                      ),
                      Container(
                        color: Colors.white,
                        width: MediaQuery.of(context).size.width * 0.5,
                        //height: MediaQuery.of(context).size.height * 0.04,
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  busStopIndex = (busStopIndex - 1) < 0
                                      ? busStops.length - 1
                                      : busStopIndex - 1;
                                  selectedBusStop = busStops[busStopIndex];
                                });
                              },
                              icon: Icon(Icons.arrow_back_ios, size: 15),
                            ),
                            DropdownButton<String>(
                              value:
                                  selectedBusStop, // Define and update selectedBusStop state variable
                              items: _buildBusStopItems(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedBusStop = newValue;
                                  busStopIndex = busStops.indexOf(newValue!);
                                });
                              },
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  busStopIndex =
                                      (busStopIndex + 1) % busStops.length;
                                  selectedBusStop = busStops[busStopIndex];
                                });
                              },
                              icon: Icon(Icons.arrow_forward_ios, size: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                      normalText(
                        'Total booking for this trip: ',
                        MediaQuery.of(context).size.width * 0.07,
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                      Container(
                        color: Colors.white,
                        width: MediaQuery.of(context).size.width * 0.15,
                        child: Row(
                          children: [
                            SizedBox(width: 10),
                            Text(
                              "${totalBooking ?? 0}",
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.07,
                                fontWeight: FontWeight.w300,
                                fontFamily: 'NewAmsterdam',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                      normalText(
                        'Booking for this stop:   ',
                        MediaQuery.of(context).size.width * 0.07,
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                      Container(
                        color: Colors.white,
                        width: MediaQuery.of(context).size.width * 0.15,
                        child: Row(
                          children: [
                            SizedBox(width: 10),
                            Text(
                              "${trackBooking ?? 0}",
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.07,
                                fontWeight: FontWeight.w300,
                                fontFamily: 'NewAmsterdam',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                      normalText(
                        'Vacancy:   ',
                        MediaQuery.of(context).size.width * 0.07,
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                      Container(
                        color: Colors.white,
                        width: MediaQuery.of(context).size.width * 0.15,
                        child: Row(
                          children: [
                            SizedBox(width: 10),
                            Text(
                              selectedMRT != null &&
                                      selectedTripNo != null &&
                                      selectedBusStop != null
                                  ? "${fullCapacity - (totalBooking != null ? totalBooking! : 0)}"
                                  : '-',
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.07,
                                fontWeight: FontWeight.w300,
                                fontFamily: 'NewAmsterdam',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.25),
                      IconButton(
                        onPressed: () {
                          if (selectedMRT != null &&
                              selectedTripNo != null &&
                              selectedBusStop != null &&
                              totalBooking! < fullCapacity) {
                            create(
                              selectedMRT!,
                              selectedTripNo!,
                              selectedBusStop!,
                            );
                          } else if (selectedMRT == null ||
                              selectedTripNo == null ||
                              selectedBusStop == null) {
                            showAlertDialog(context);
                          } else if (totalBooking! >= fullCapacity) {
                            fullAlertDialog(context);
                          }
                        },
                        icon: Container(
                          height: MediaQuery.of(context).size.height * 0.07,
                          width: MediaQuery.of(context).size.width * 0.2,
                          color: Colors.green,
                          child: Align(
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.add_outlined,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.1),
                      IconButton(
                        onPressed: () {
                          if (selectedMRT != null &&
                              selectedTripNo != null &&
                              selectedBusStop != null) {
                            minus(
                              selectedMRT!,
                              selectedTripNo!,
                              selectedBusStop!,
                            );
                          } else if (selectedMRT == null ||
                              selectedTripNo == null ||
                              selectedBusStop == null) {
                            showAlertDialog(context);
                          }
                          if (trackBooking == 0) {
                            showVoidDialog(context);
                          }
                        },
                        icon: Container(
                          height: MediaQuery.of(context).size.height * 0.04,
                          width: MediaQuery.of(context).size.width * 0.15,
                          color: Colors.red,
                          child: Align(
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.remove_outlined,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.55),
                      Text(
                        formatTimesecond(now),
                        style: TextStyle(
                          fontFamily: 'Tomorrow',
                          fontSize: MediaQuery.of(context).size.width * 0.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
