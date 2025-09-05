import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:driver_10_updated/amplifyconfiguration.dart';
import 'package:driver_10_updated/models/ModelProvider.dart';
import 'package:driver_10_updated/pages/busdata.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:uuid/uuid.dart';

class Map_Page extends StatefulWidget {
  const Map_Page({super.key});

  @override
  State<Map_Page> createState() => _Map_PageState();
}

class _Map_PageState extends State<Map_Page> with WidgetsBindingObserver {
  final ScrollController controller = ScrollController();
  final BusInfo _BusInfo = BusInfo();
  String? selectedMRT;
  int? selectedTripNo;
  String? selectedBusStop;
  int BusStop_Index = 8;
  final int CLE_TripNo = 4;
  final int KAP_TripNo = 13;
  String? BookingID;
  List<String> BusStops = [];
  int? trackBooking;
  late Timer _timer;
  Timer? _clocktimer;
  int? totalBooking;
  bool loading_totalcount = true;
  bool loading_count = true;
  int full_capacity = 30;
  List<DateTime> KAP_AT = [];
  List<DateTime> CLE_AT = [];
  DateTime now = DateTime.now();
  Duration timeUpdateInterval = Duration(seconds: 1);
  Duration apiFetchInterval = Duration(minutes: 1);
  int secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BusStops = _BusInfo.BusStop;
    BusStops = BusStops.sublist(2); //sublist used to start from index 2
    selectedBusStop = BusStops[BusStop_Index];
    KAP_AT = _BusInfo.KAPDepartureTime;
    CLE_AT = _BusInfo.CLEDepartureTime;
    _configureAmplify();

    _timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      _updateTotalBooking();
      _updateBooking();
    });

    getTime().then((_) {
      _clocktimer = Timer.periodic(timeUpdateInterval, (timer) {
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
    _clocktimer?.cancel();
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
            await getcountCLE(selectedTripNo!, selectedBusStop!) ?? 0;
      } else {
        trackBooking =
            await getcountKAP(selectedTripNo!, selectedBusStop!) ?? 0;
      }
      setState(() {
        trackBooking = trackBooking;
        loading_count = false;
      });
    }
  }

  void _updateTotalBooking() async {
    if (selectedMRT != null && selectedTripNo != null) {
      totalBooking = await countBooking(selectedMRT!, selectedTripNo!);
    }
    setState(() {
      totalBooking = totalBooking;
      loading_totalcount = false;
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

    print('Amplify configured');
  }

  Future<void> create(String _MRTStation, int _TripNo, String _BusStop) async {
    try {
      final model = BOOKINGDETAILS5(
        id: Uuid().v4(),
        MRTStation: _MRTStation,
        TripNo: _TripNo,
        BusStop: _BusStop,
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
        BookingID = id;
      });
      safePrint('Mutation result: $BookingID');

      // Ensure count update happens only after the booking creation is confirmed
      if (_MRTStation == 'KAP') {
        await countKAP(_TripNo, _BusStop);
      } else {
        await countCLE(_TripNo, _BusStop);
      }
    } on ApiException catch (e) {
      safePrint('Mutation failed: $e');
    }
  }

  Future<BOOKINGDETAILS5?> readByID() async {
    final request = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.ID.eq(BookingID),
    );
    final response = await Amplify.API.query(request: request).response;
    final data = response.data?.items.firstOrNull;
    return data;
  }

  Future<BOOKINGDETAILS5?> Search_Instance(
    String MRT,
    int TripNo,
    String BusStop,
  ) async {
    final request = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: (BOOKINGDETAILS5.MRTSTATION
          .eq(MRT)
          .and(
            BOOKINGDETAILS5.TRIPNO
                .eq(TripNo)
                .and(BOOKINGDETAILS5.BUSSTOP.eq(BusStop)),
          )),
    );
    final response = await Amplify.API.query(request: request).response;
    final data = response.data?.items.firstOrNull;
    return data;
  }

  Future<int?> countBooking(String MRT, int TripNo) async {
    int? count;
    try {
      final request = ModelQueries.list(
        BOOKINGDETAILS5.classType,
        where: BOOKINGDETAILS5.MRTSTATION
            .eq(MRT)
            .and(BOOKINGDETAILS5.TRIPNO.eq(TripNo)),
      );
      final response = await Amplify.API.query(request: request).response;
      final data = response.data?.items;

      if (data != null) {
        count = data.length;
        print('$count');
      } else
        count = 0;
    } catch (e) {
      print('$e');
    }
    return count;
  }

  Future<void> Minus(String _MRT, int _TripNo, String _BusStop) async {
    final BOOKINGDETAILS5? bookingToDelete = await Search_Instance(
      _MRT,
      _TripNo,
      _BusStop,
    );
    if (bookingToDelete != null) {
      final request = ModelMutations.delete(bookingToDelete);
      final response = await Amplify.API.mutate(request: request).response;
      if (bookingToDelete.MRTStation == 'KAP')
        countKAP(bookingToDelete.TripNo, bookingToDelete.BusStop);
      else
        countCLE(bookingToDelete.TripNo, bookingToDelete.BusStop);
    } else {
      print('No booking deleted');
    }
  }

  Future<int?> getcountCLE(int _TripNo, String _BusStop) async {
    int? count;
    try {
      final request = ModelQueries.list(
        BOOKINGDETAILS5.classType,
        where: BOOKINGDETAILS5.MRTSTATION
            .eq('CLE')
            .and(
              BOOKINGDETAILS5.TRIPNO
                  .eq(_TripNo)
                  .and(BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
            ),
      );
      final response = await Amplify.API.query(request: request).response;
      final data = response.data?.items;

      if (data != null) {
        count = data.length;
        print('$count');
      } else {
        count = 0;
      }
    } catch (e) {
      print('$e');
    }
    return count;
  }

  Future<int?> countCLE(int _TripNo, String _BusStop) async {
    int? count;
    // Read if there is a row
    final request1 = ModelQueries.list(
      CLEAfternoon.classType,
      where: CLEAfternoon.TRIPNO
          .eq(_TripNo)
          .and(CLEAfternoon.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');

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
          .and(BOOKINGDETAILS5.TRIPNO.eq(_TripNo))
          .and(BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    if (data2 != null) {
      count = data2.length;
      print('$count');
    } else {
      count = 0;
    }

    // If count is greater than 0, create the row
    if (count > 0) {
      final model = CLEAfternoon(
        BusStop: _BusStop,
        TripNo: _TripNo,
        Count: count,
      );
      final request4 = ModelMutations.create(model);
      final response4 = await Amplify.API.mutate(request: request4).response;
      final createdCLE = response4.data;
    }

    return count;
  }

  Future<int?> getcountKAP(int _TripNo, String _BusStop) async {
    int? count;
    try {
      final request = ModelQueries.list(
        BOOKINGDETAILS5.classType,
        where: BOOKINGDETAILS5.MRTSTATION
            .eq('KAP')
            .and(
              BOOKINGDETAILS5.TRIPNO
                  .eq(_TripNo)
                  .and(BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
            ),
      );
      final response = await Amplify.API.query(request: request).response;
      final data = response.data?.items;

      if (data != null) {
        count = data.length;
        print('$count');
      } else {
        count = 0;
      }
    } catch (e) {
      print('$e');
    }
    return count;
  }

  Future<int?> countKAP(int _TripNo, String _BusStop) async {
    int? count;
    // Read if there is a row
    final request1 = ModelQueries.list(
      KAPAfternoon.classType,
      where: KAPAfternoon.TRIPNO
          .eq(_TripNo)
          .and(KAPAfternoon.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');

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
          .and(BOOKINGDETAILS5.TRIPNO.eq(_TripNo))
          .and(BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    if (data2 != null) {
      count = data2.length;
      print('$count');
    } else {
      count = 0;
    }
    // If count is greater than 0, create the row
    if (count > 0) {
      final model = KAPAfternoon(
        BusStop: _BusStop,
        TripNo: _TripNo,
        Count: count,
      );
      final request4 = ModelMutations.create(model);
      final response4 = await Amplify.API.mutate(request: request4).response;
      final createdKAP = response4.data;
    }
    print("Returning KAP count");
    print("$count");
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
    return BusStops.map((String busStop) {
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
      return _BusInfo.KAPDepartureTime;
    } else {
      return _BusInfo.CLEDepartureTime;
    }
  }

  Future<void> getTime() async {
    try {
      final uri = Uri.parse(
        'https://www.timeapi.io/api/time/current/zone?timeZone=ASIA%2FSINGAPORE',
      );
      // final uri = Uri.parse('https://worldtimeapi.org/api/timezone/Singapore');
      print("Printing URI");
      print(uri);
      final response = await get(uri);
      print("Printing response");
      print(response);

      // Response response = await get(
      //     Uri.parse('https://worldtimeapi.org/api/timezone/Singapore'));
      print(response.body);
      Map data = jsonDecode(response.body);
      print(data);
      String datetime =
          data['dateTime']; //timeapi.io uses dateTime not datetime
      //String offset = data['utc_offset'].substring(1, 3);

      setState(() {
        now = DateTime.parse(datetime);
        //now = now.add(Duration(hours: int.parse(offset)));
        print('Printing Time: $now');
      });
    } catch (e) {
      print('caught error: $e');
    }
  }

  void updateTimeManually() {
    if (mounted) {
      setState(() {
        now = now!.add(timeUpdateInterval);
      });
    }
  }

  Color? generateColor(List<DateTime> DT, int selectedTripNo) {
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

    DateTime departureTime = DT[selectedTripNo - 1];
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

  Widget DrawLine() {
    return Column(
      // Use Row here
      children: [
        DrawWidth(0.025),
        Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: 2,
          color: Colors.black,
        ),
      ],
    );
  }

  Widget AddTitle(String title, double fontsize) {
    return Align(
      alignment: Alignment.center,
      child: Text(
        '$title',
        style: TextStyle(
          fontSize: fontsize,
          fontWeight: FontWeight.bold,
          fontFamily: 'Timmana',
        ),
      ),
    );
  }

  Widget DrawWidth(double size) {
    return SizedBox(width: MediaQuery.of(context).size.width * size);
  }

  Widget DrawHeight(double size) {
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

  Widget NormalText(String text, double fontsize) {
    return Text(
      '$text',
      style: TextStyle(
        fontSize: fontsize,
        fontWeight: FontWeight.w300,
        fontFamily: 'NewAmsterdam',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("TrackBooking & TotalBooking");
    print("$trackBooking");
    print("$totalBooking");
    return Scaffold(
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Container(
              color: (getDepartureTimes() != null && selectedTripNo != null)
                  ? generateColor(getDepartureTimes(), selectedTripNo!)
                  : Colors.lightBlue[100],
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  AddTitle(
                    'MooBus Saftey Operator',
                    MediaQuery.of(context).size.width * 0.1,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      AddTitle(
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
                  DrawLine(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  AddTitle(
                    'Selected Route',
                    MediaQuery.of(context).size.width * 0.08,
                  ),
                  Row(
                    children: [
                      DrawWidth(0.2),
                      NormalText(
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
                  DrawLine(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Row(
                    children: [
                      DrawWidth(0.1),
                      NormalText(
                        'TRIP NUMBER',
                        MediaQuery.of(context).size.width * 0.07,
                      ),
                      DrawWidth(0.1),
                      NormalText(
                        'DEPARTURE TIME',
                        MediaQuery.of(context).size.width * 0.07,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      DrawWidth(0.25),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.2,
                        height:
                            MediaQuery.of(context).size.height *
                            0.05, // Fixed width for consistency
                        child: DropdownButton<int>(
                          value: selectedTripNo,
                          items: selectedMRT == 'CLE'
                              ? _buildTripNoItems(
                                  _BusInfo.CLEDepartureTime.length,
                                )
                              : selectedMRT == 'KAP'
                              ? _buildTripNoItems(
                                  _BusInfo.KAPDepartureTime.length,
                                )
                              : [],
                          onChanged: (int? newValue) {
                            setState(() {
                              selectedTripNo = newValue;
                            });
                          },
                        ),
                      ),
                      DrawWidth(0.1),
                      if (selectedMRT != null && selectedTripNo != null)
                        Text(
                          selectedMRT == 'CLE'
                              ? '${formatTime(CLE_AT[selectedTripNo! - 1])}'
                              : '${formatTime(KAP_AT[selectedTripNo! - 1])}',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.06,
                            fontWeight: FontWeight.w300,
                            fontFamily: 'NewAmsterdam',
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  DrawLine(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Column(
                    children: [
                      AddTitle(
                        'Arriving Bus Stop Info',
                        MediaQuery.of(context).size.width * 0.08,
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                      NormalText(
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
                                  BusStop_Index = (BusStop_Index - 1) < 0
                                      ? BusStops.length - 1
                                      : BusStop_Index - 1;
                                  selectedBusStop = BusStops[BusStop_Index];
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
                                  BusStop_Index = BusStops.indexOf(newValue!);
                                });
                              },
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  BusStop_Index =
                                      (BusStop_Index + 1) % BusStops.length;
                                  selectedBusStop = BusStops[BusStop_Index];
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
                      NormalText(
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
                              "${totalBooking != null ? totalBooking : 0}",
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
                      NormalText(
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
                              "${trackBooking != null ? trackBooking : 0}",
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
                      NormalText(
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
                                  ? "${full_capacity - (totalBooking != null ? totalBooking! : 0)}"
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
                              totalBooking! < full_capacity) {
                            create(
                              selectedMRT!,
                              selectedTripNo!,
                              selectedBusStop!,
                            );
                          } else if (selectedMRT == null ||
                              selectedTripNo == null ||
                              selectedBusStop == null) {
                            showAlertDialog(context);
                          } else if (totalBooking! >= full_capacity) {
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
                            Minus(
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
                        '${formatTimesecond(now)}',
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
