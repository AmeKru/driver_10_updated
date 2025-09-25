import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:driver_10_updated/amplifyconfiguration.dart';
import 'package:driver_10_updated/models/model_provider.dart';
import 'package:driver_10_updated/utils/bus_data.dart';
import 'package:driver_10_updated/utils/text_sizing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:uuid/uuid.dart';

////////////////////////////////////////////////////////////
// Afternoon Page

class AfternoonPage extends StatefulWidget {
  const AfternoonPage({super.key});

  @override
  State<AfternoonPage> createState() => _AfternoonPageState();
}

class _AfternoonPageState extends State<AfternoonPage>
    with WidgetsBindingObserver {
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

  ////////////////////////////////////////////////////////////
  // API and Amplify

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The app is resumed; re-fetch the time from the API
      getTime();
    }
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

  ////////////////////////////////////////////////////////////
  // updateBookings

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

  ////////////////////////////////////////////////////////////////////
  // create

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

  ////////////////////////////////////////////////////////////////////
  // count Bookings

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

  ////////////////////////////////////////////////////////////////////
  // getters

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

  ////////////////////////////////////////////////////////////////////
  // Dropdown menu items

  List<DropdownMenuItem<int>> _buildTripNoItems(int tripNo) {
    return List<DropdownMenuItem<int>>.generate(
      tripNo,
      (int index) => DropdownMenuItem<int>(
        value: index + 1,
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: TextSizing.fontSizeMiniText(context),
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
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
            fontSize: TextSizing.fontSizeMiniText(context),
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
      );
    }).toList();
  }

  ////////////////////////////////////////////////////////////////////
  // Dialogs

  void showVoidDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          actionsAlignment: MainAxisAlignment.center,
          title: Text(
            'ALERT',
            style: TextStyle(
              fontSize: TextSizing.fontSizeText(context),
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'No Booking to delete',
            style: TextStyle(
              fontSize: TextSizing.fontSizeMiniText(context),
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: TextSizing.fontSizeMiniText(context),
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff014689),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        //callback function that returns a widget
        return AlertDialog(
          actionsAlignment: MainAxisAlignment.center,
          title: Text(
            'ALERT',
            style: TextStyle(
              fontSize: TextSizing.fontSizeText(context),
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Please select MRT, Bus Stop,\nand Trip Number.',
            style: TextStyle(
              fontSize: TextSizing.fontSizeMiniText(context),
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: TextSizing.fontSizeMiniText(context),
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff014689),
                ),
              ),
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
          actionsAlignment: MainAxisAlignment.center,
          title: Text(
            'ALERT',
            style: TextStyle(
              fontSize: TextSizing.fontSizeText(context),
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Booking Full',
            style: TextStyle(
              fontSize: TextSizing.fontSizeMiniText(context),
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: TextSizing.fontSizeMiniText(context),
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff014689),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  ////////////////////////////////////////////////////////////////////
  // generated colours, will be used as background colour and to check tickets?

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

  ////////////////////////////////////////////////////////////
  // For Format

  Widget drawLine() {
    return Column(
      children: [
        Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: TextSizing.fontSizeMiniText(context) * 0.1,
          color: Colors.black,
        ),
      ],
    );
  }

  //////////////////////////////////////////////////////////////////////
  // So Time looks nice

  String formatTime(DateTime time) {
    String hour = time.hour.toString().padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String formatTimeSecond(DateTime time) {
    String hour = time.hour.toString().padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');
    String sec = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$sec';
  }

  ///////////////////////////////////////////////////////////////////////
  // Layout of page

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print("TrackBooking & TotalBooking");
      print("$trackBooking");

      print("$totalBooking");
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: TextSizing.fontSizeHeading(context) * 1.75,
        title: Stack(
          children: [
            // Centered app title with bus icon
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: TextSizing.fontSizeHeading(context),
                  ),
                  SizedBox(width: TextSizing.fontSizeMiniText(context) * 0.3),
                  Text(
                    'MooBus Safety Operator',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: Colors.white,
                      fontSize: TextSizing.fontSizeHeading(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        automaticallyImplyLeading:
            false, // Prevents default back arrow or drawer icon
        backgroundColor: Colors.black, // Custom app bar color
      ),
      backgroundColor: (selectedTripNo != null)
          ? generateColor(getDepartureTimes(), selectedTripNo!)
          : Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: TextSizing.fontSizeText(context)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      'Tracking (Afternoon)',
                      style: TextStyle(
                        fontSize: TextSizing.fontSizeText(context),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: TextSizing.fontSizeText(context)),
                drawLine(),
                SizedBox(height: TextSizing.fontSizeMiniText(context)),

                Text(
                  'Select Route',
                  style: TextStyle(
                    fontSize: TextSizing.fontSizeText(context),
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Roboto',
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'CAMPUS - ',
                      style: TextStyle(
                        fontSize: TextSizing.fontSizeMiniText(context),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    Container(
                      color: Colors.black,
                      child: DropdownButton<String>(
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(
                          TextSizing.fontSizeMiniText(context) * 0.2,
                        ),
                        style: TextStyle(color: Colors.white), //  text color
                        dropdownColor: Colors.black, //  menu background
                        iconEnabledColor: Colors.white, //  arrow color
                        focusColor: Colors.black,
                        value: selectedMRT,
                        items: ['CLE', 'KAP'].map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: TextSizing.fontSizeMiniText(context),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Roboto',
                                color: Colors.white,
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
                        underline: SizedBox(),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: TextSizing.fontSizeMiniText(context)),
                drawLine(),
                SizedBox(height: TextSizing.fontSizeMiniText(context)),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          child: Text(
                            'TRIP NUMBER',
                            style: TextStyle(
                              fontSize: TextSizing.fontSizeText(context),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                        SizedBox(
                          height: TextSizing.fontSizeHeading(context),
                          width: TextSizing.fontSizeHeading(context) * 2,
                          child: Center(
                            child: Container(
                              color: Colors.black,
                              child: DropdownButton<int>(
                                alignment: Alignment.center,
                                padding: EdgeInsets.all(
                                  TextSizing.fontSizeMiniText(context) * 0.2,
                                ),
                                value: selectedTripNo,
                                isExpanded:
                                    true, // makes text wrap nicely if long
                                dropdownColor: Colors.black, // menu background
                                iconEnabledColor: Colors.white, // arrow color
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Roboto',
                                ),

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
                                underline: SizedBox(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          child: Center(
                            child: Text(
                              'DEPARTURE TIME',
                              style: TextStyle(
                                fontSize: TextSizing.fontSizeText(context),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                        ),
                        if (selectedMRT != null && selectedTripNo != null)
                          Container(
                            width: TextSizing.fontSizeHeading(context) * 2,
                            height: TextSizing.fontSizeHeading(context),

                            color: Colors.white,

                            child: Center(
                              child: Text(
                                selectedMRT == 'CLE'
                                    ? formatTime(
                                        arrivalTimeCLE[selectedTripNo! - 1],
                                      )
                                    : formatTime(
                                        arrivalTimeKAP[selectedTripNo! - 1],
                                      ),
                                style: TextStyle(
                                  fontSize: TextSizing.fontSizeMiniText(
                                    context,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                          ),
                        if (!(selectedMRT != null && selectedTripNo != null))
                          SizedBox(
                            width: TextSizing.fontSizeHeading(context) * 2,
                            height: TextSizing.fontSizeHeading(context),
                            child: Center(child: Text(' ')),
                          ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: TextSizing.fontSizeMiniText(context)),
                drawLine(),
                SizedBox(height: TextSizing.fontSizeMiniText(context)),

                Column(
                  children: [
                    Text(
                      'Arriving Bus Stop Info',
                      style: TextStyle(
                        fontSize: TextSizing.fontSizeText(context),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),

                    SizedBox(height: TextSizing.fontSizeMiniText(context)),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: TextSizing.fontSizeText(context),
                              child: Text(
                                'Bus Stop:',
                                style: TextStyle(
                                  fontSize: TextSizing.fontSizeMiniText(
                                    context,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),

                            SizedBox(
                              height: TextSizing.fontSizeMiniText(context),
                            ),

                            SizedBox(
                              height: TextSizing.fontSizeText(context),
                              child: Text(
                                'Total booking for this trip:',
                                style: TextStyle(
                                  fontSize: TextSizing.fontSizeMiniText(
                                    context,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),

                            SizedBox(
                              height: TextSizing.fontSizeMiniText(context),
                            ),

                            SizedBox(
                              height: TextSizing.fontSizeText(context),
                              child: Text(
                                'Booking for this stop:',
                                style: TextStyle(
                                  fontSize: TextSizing.fontSizeMiniText(
                                    context,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),

                            SizedBox(
                              height: TextSizing.fontSizeMiniText(context),
                            ),

                            SizedBox(
                              height: TextSizing.fontSizeText(context),
                              child: Text(
                                'Vacancy:',
                                style: TextStyle(
                                  fontSize: TextSizing.fontSizeMiniText(
                                    context,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),

                            SizedBox(height: TextSizing.fontSizeText(context)),
                          ],
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              color: Colors.black,
                              width: TextSizing.fontSizeText(context) * 5,
                              height: TextSizing.fontSizeText(context),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        busStopIndex = (busStopIndex - 1) < 0
                                            ? busStops.length - 1
                                            : busStopIndex - 1;
                                        selectedBusStop =
                                            busStops[busStopIndex];
                                      });
                                    },
                                    icon: Icon(
                                      Icons.arrow_back_ios,
                                      color: Colors.white,
                                      size: TextSizing.fontSizeMiniText(
                                        context,
                                      ),
                                    ),
                                  ),
                                  DropdownButton<String>(
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.all(
                                      TextSizing.fontSizeMiniText(context) *
                                          0.2,
                                    ),

                                    value:
                                        selectedBusStop, // Define and update selectedBusStop state variable

                                    dropdownColor:
                                        Colors.black, // menu background
                                    iconEnabledColor:
                                        Colors.white, // arrow color
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Roboto',
                                    ),

                                    items: _buildBusStopItems(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        selectedBusStop = newValue;
                                        busStopIndex = busStops.indexOf(
                                          newValue!,
                                        );
                                      });
                                    },
                                    underline: SizedBox(),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        busStopIndex =
                                            (busStopIndex + 1) %
                                            busStops.length;
                                        selectedBusStop =
                                            busStops[busStopIndex];
                                      });
                                    },
                                    icon: Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white,
                                      size: TextSizing.fontSizeMiniText(
                                        context,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(
                              height: TextSizing.fontSizeMiniText(context),
                            ),

                            Container(
                              color: Colors.white,
                              width: TextSizing.fontSizeText(context) * 5,
                              height: TextSizing.fontSizeText(context),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "${totalBooking ?? 0}",
                                    style: TextStyle(
                                      fontSize: TextSizing.fontSizeMiniText(
                                        context,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(
                              height: TextSizing.fontSizeMiniText(context),
                            ),

                            Container(
                              color: Colors.white,
                              width: TextSizing.fontSizeText(context) * 5,
                              height: TextSizing.fontSizeText(context),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "${trackBooking ?? 0}",
                                    style: TextStyle(
                                      fontSize: TextSizing.fontSizeMiniText(
                                        context,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(
                              height: TextSizing.fontSizeMiniText(context),
                            ),

                            Container(
                              color: Colors.white,
                              width: TextSizing.fontSizeText(context) * 5,
                              height: TextSizing.fontSizeText(context),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    selectedMRT != null &&
                                            selectedTripNo != null &&
                                            selectedBusStop != null
                                        ? "${fullCapacity - (totalBooking != null ? totalBooking! : 0)}"
                                        : '-',
                                    style: TextStyle(
                                      fontSize: TextSizing.fontSizeMiniText(
                                        context,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: TextSizing.fontSizeText(context)),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: TextSizing.fontSizeText(context)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                            height: TextSizing.fontSizeText(context) * 2,
                            width: TextSizing.fontSizeText(context) * 3,
                            color: Colors.green,
                            child: Align(
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.add_outlined,
                                color: Colors.white,
                                size: TextSizing.fontSizeText(context) * 2,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: TextSizing.fontSizeText(context)),
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
                            height: TextSizing.fontSizeText(context) * 2,
                            width: TextSizing.fontSizeText(context) * 3,
                            color: Colors.red,
                            child: Align(
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.remove_outlined,
                                color: Colors.white,
                                size: TextSizing.fontSizeText(context) * 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: TextSizing.fontSizeText(context)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatTimeSecond(now),
                          style: TextStyle(
                            fontSize: TextSizing.fontSizeText(context),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: TextSizing.fontSizeText(context)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
