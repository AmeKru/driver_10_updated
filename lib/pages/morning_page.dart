import 'dart:async';
import 'dart:convert';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:driver_10_updated/amplifyconfiguration.dart';
import 'package:driver_10_updated/global.dart';
import 'package:driver_10_updated/models/model_provider.dart';
import 'package:driver_10_updated/utils/bus_data.dart';
import 'package:driver_10_updated/utils/text_sizing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:uuid/uuid.dart';

import 'afternoon_page.dart';

////////////////////////////////////////////////////////////
// Morning Page

class MorningPage extends StatefulWidget {
  const MorningPage({super.key});

  @override
  State<MorningPage> createState() => _MorningPageState();
}

class _MorningPageState extends State<MorningPage> with WidgetsBindingObserver {
  final ScrollController controller = ScrollController();
  final BusInfo busInfo = BusInfo();
  String? selectedMRT;
  int? selectedTripNo;
  String? selectedBusStop;
  int busStopIndex = 8;
  final int tripNoCLE = 1;
  final int tripNoKAP = 1;
  List<String> busStops = [];
  late Timer _timer;
  Timer? _clockTimer;
  List<DateTime> dateTimeKAP = [];
  List<DateTime> dateTimeCLE = [];
  DateTime now = DateTime.now();
  Duration timeUpdateInterval = Duration(seconds: 1);
  Duration apiFetchInterval = Duration(minutes: 1);
  int secondsElapsed = 0;
  int selectedCrowdLevel = -1;
  bool _selection = false;
  int count = 0;

  @override
  void initState() {
    super.initState();
    _schedulePageChange(
      screenTimeHour,
      screenTimeMin,
    ); //  change page at certain time

    WidgetsBinding.instance.addObserver(this);
    _configureAmplify();
    busStops = busInfo.busStop;
    busStops = busStops.sublist(2); //sublist used to start from index 2
    selectedBusStop = busStops[busStopIndex];
    dateTimeKAP = busInfo.arrivalTimeKAP;
    if (kDebugMode) {
      print(dateTimeKAP);
    }
    dateTimeCLE = busInfo.arrivalTimeCLE;

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

  ////////////////////////////////////////////////////////////
  // To switch to other page when time is right

  void _schedulePageChange(int hour, int minute) {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day, hour, minute);

    // If target time already passed today, do nothing (or schedule for tomorrow)
    if (target.isBefore(now)) return;

    final delay = target.difference(now);

    _timer = Timer(delay, () {
      if (!mounted) return; //  safe check
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AfternoonPage()),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // called when app comes back from background
      _checkAndNavigate();
    }
  }

  void _checkAndNavigate() {
    final now = DateTime.now();
    if (now.hour >= screenTimeHour && now.minute >= screenTimeMin) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AfternoonPage()),
      );
    }
  }

  @override
  void dispose() {
    _timer.cancel(); //  clean up timer when widget is disposed
    super.dispose();
  }

  ////////////////////////////////////////////////////////////
  // Amplify

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
  // create

  Future<void> create(
    String mrtStation,
    int tripNo,
    String busStop,
    int count,
  ) async {
    try {
      if (mrtStation == 'KAP') {
        final model = KAPMorning(
          id: Uuid().v4(),
          TripNo: tripNo,
          BusStop: busStop,
          Count: count,
        );

        final request = ModelMutations.create(model);
        final response = await Amplify.API.mutate(request: request).response;

        final createdBOOKINGDETAILS5 = response.data;
        if (createdBOOKINGDETAILS5 == null) {
          safePrint('errors: ${response.errors}');
          return;
        }
      } else {
        final model = CLEMorning(
          id: Uuid().v4(),
          TripNo: tripNo,
          BusStop: busStop,
          Count: count,
        );

        final request = ModelMutations.create(model);
        final response = await Amplify.API.mutate(request: request).response;

        final createdBOOKINGDETAILS5 = response.data;
        if (createdBOOKINGDETAILS5 == null) {
          safePrint('errors: ${response.errors}');
          return;
        }
      }
    } on ApiException catch (e) {
      safePrint('Mutation failed: $e');
    }
  }

  ////////////////////////////////////////////////////////////
  // Some methods

  List<DateTime> getDepartureTimes() {
    if (selectedMRT == 'KAP') {
      return busInfo.arrivalTimeKAP;
    } else {
      return busInfo.arrivalTimeCLE;
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
      }
      if (kDebugMode) {
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
    setState(() {
      now = now.add(timeUpdateInterval);
    });
  }

  void selectCrowdLevel(int index) {
    if (!_selection) {
      // Only allow selection if not confirmed
      setState(() {
        selectedCrowdLevel = index;
      });
    }
  }

  void passengerCount(int count) {
    setState(() {
      count = count;
    });
  }

  ////////////////////////////////////////////////////////////
  // Dialogs

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
                  fontSize: TextSizing.fontSizeText(context),
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

  void _showConfirmationDialog(mrt, tripNo, busStop) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Confirmation',
            style: TextStyle(
              fontSize: TextSizing.fontSizeText(context),
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Confirm Selection',
            style: TextStyle(
              fontSize: TextSizing.fontSizeMiniText(context),
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog on cancel
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: TextSizing.fontSizeMiniText(context),
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff014689),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selection = true;
                });
                create(mrt, tripNo, busStop, count);
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: TextSizing.fontSizeMiniText(context),
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff014689),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNewTripSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Choose new trip',
            style: TextStyle(
              fontSize: TextSizing.fontSizeText(context),
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Confirm choose new trip',
            style: TextStyle(
              fontSize: TextSizing.fontSizeMiniText(context),
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog on cancel
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: TextSizing.fontSizeMiniText(context),
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff014689),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selection = false;
                  selectedCrowdLevel = -1;
                });
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: TextSizing.fontSizeMiniText(context),
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff014689),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  ////////////////////////////////////////////////////////////
  // Dropdown Menus

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

  ////////////////////////////////////////////////////////////
  // Layout
  //TODO: Add automatic switch to other map page

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: Colors.white,
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
                      'Tracking (Morning)',
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
                SizedBox(height: TextSizing.fontSizeText(context)),

                Text(
                  'Select Route',
                  style: TextStyle(
                    fontSize: TextSizing.fontSizeText(context),
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Roboto',
                  ),
                ),

                SizedBox(height: TextSizing.fontSizeMiniText(context)),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                    Text(
                      ' - CAMPUS',
                      style: TextStyle(
                        fontSize: TextSizing.fontSizeMiniText(context),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: TextSizing.fontSizeText(context)),
                drawLine(),
                SizedBox(height: TextSizing.fontSizeText(context)),

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
                        SizedBox(height: TextSizing.fontSizeMiniText(context)),
                        SizedBox(
                          height: TextSizing.fontSizeHeading(context),
                          width: TextSizing.fontSizeHeading(context) * 2,
                          child: Center(
                            child: Container(
                              color: Colors.black,

                              child: _selection
                                  ? IgnorePointer(
                                      ignoring:
                                          true, // Disable user interaction
                                      child: DropdownButton<int>(
                                        value: selectedTripNo,
                                        items: selectedMRT == 'CLE'
                                            ? _buildTripNoItems(
                                                dateTimeCLE.length,
                                              )
                                            : selectedMRT == 'KAP'
                                            ? _buildTripNoItems(
                                                dateTimeKAP.length,
                                              )
                                            : [],
                                        onChanged:
                                            null, // Disable the onChanged function
                                      ),
                                    )
                                  : DropdownButton<int>(
                                      alignment: Alignment.center,
                                      padding: EdgeInsets.all(
                                        TextSizing.fontSizeMiniText(context) *
                                            0.2,
                                      ),
                                      value: selectedTripNo,
                                      isExpanded:
                                          true, // makes text wrap nicely if long
                                      dropdownColor:
                                          Colors.black, // menu background
                                      iconEnabledColor:
                                          Colors.white, // arrow color
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Roboto',
                                      ),

                                      items: selectedMRT == 'CLE'
                                          ? _buildTripNoItems(
                                              dateTimeCLE.length,
                                            )
                                          : selectedMRT == 'KAP'
                                          ? _buildTripNoItems(
                                              dateTimeKAP.length,
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
                        SizedBox(height: TextSizing.fontSizeMiniText(context)),
                        if (selectedMRT != null && selectedTripNo != null)
                          Container(
                            width: TextSizing.fontSizeHeading(context) * 2,
                            height: TextSizing.fontSizeHeading(context),

                            color: Colors.white,

                            child: Center(
                              child: Text(
                                selectedMRT == 'CLE'
                                    ? formatTime(
                                        dateTimeCLE[selectedTripNo! - 1],
                                      )
                                    : formatTime(
                                        dateTimeKAP[selectedTripNo! - 1],
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

                SizedBox(height: TextSizing.fontSizeText(context)),
                drawLine(),
                SizedBox(height: TextSizing.fontSizeHeading(context) * 2),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!_selection) {
                          if (selectedMRT == null || selectedTripNo == null) {
                            showAlertDialog(context);
                          } else {
                            selectCrowdLevel(0); // Less crowded
                            passengerCount(7);
                          }
                        }
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.25,
                        decoration: BoxDecoration(
                          color: selectedCrowdLevel == 0
                              ? Colors.green[300]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedCrowdLevel == 0
                                ? Colors.green[800]!
                                : Colors.grey,
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Icon(
                              selectedCrowdLevel == 0
                                  ? Icons.sentiment_satisfied_alt_rounded
                                  : Icons.sentiment_satisfied,
                              color: selectedCrowdLevel == 0
                                  ? Colors.green[800]
                                  : Colors.grey,
                              size: TextSizing.fontSizeHeading(context),
                            ),
                            SizedBox(
                              height:
                                  TextSizing.fontSizeMiniText(context) * 0.2,
                            ),
                            Text(
                              '< half',
                              style: TextStyle(
                                color: selectedCrowdLevel == 0
                                    ? Colors.green[800]
                                    : Colors.grey,
                                fontSize: TextSizing.fontSizeMiniText(context),
                                fontFamily: 'Roboto',
                                fontWeight: selectedCrowdLevel == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        if (!_selection) {
                          if (selectedMRT == null || selectedTripNo == null) {
                            showAlertDialog(context);
                          } else {
                            selectCrowdLevel(1); // Crowded
                            passengerCount(15);
                          }
                        }
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.25,
                        decoration: BoxDecoration(
                          color: selectedCrowdLevel == 1
                              ? Colors.orange[300]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedCrowdLevel == 1
                                ? Colors.orange[800]!
                                : Colors.grey,
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Icon(
                              selectedCrowdLevel == 1
                                  ? Icons.sentiment_neutral_outlined
                                  : Icons.sentiment_neutral,
                              color: selectedCrowdLevel == 1
                                  ? Colors.orange[800]
                                  : Colors.grey,
                              size: TextSizing.fontSizeHeading(context),
                            ),
                            SizedBox(
                              height:
                                  TextSizing.fontSizeMiniText(context) * 0.2,
                            ),
                            Text(
                              '>= half',
                              style: TextStyle(
                                color: selectedCrowdLevel == 1
                                    ? Colors.orange[800]
                                    : Colors.grey,
                                fontSize: TextSizing.fontSizeMiniText(context),
                                fontFamily: 'Roboto',
                                fontWeight: selectedCrowdLevel == 1
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        if (!_selection) {
                          if (selectedMRT == null || selectedTripNo == null) {
                            showAlertDialog(context);
                          } else {
                            selectCrowdLevel(2); // Very Crowded
                            passengerCount(30);
                          }
                        }
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.25,
                        decoration: BoxDecoration(
                          color: selectedCrowdLevel == 2
                              ? Colors.red[300]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedCrowdLevel == 2
                                ? Colors.red[900]!
                                : Colors.grey,
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Icon(
                              selectedCrowdLevel == 2
                                  ? Icons.sentiment_dissatisfied_rounded
                                  : Icons.sentiment_dissatisfied,
                              color: selectedCrowdLevel == 2
                                  ? Colors.red[900]
                                  : Colors.grey,
                              size: TextSizing.fontSizeHeading(context),
                            ),
                            SizedBox(
                              height:
                                  TextSizing.fontSizeMiniText(context) * 0.2,
                            ),
                            Text(
                              'full',
                              style: TextStyle(
                                color: selectedCrowdLevel == 2
                                    ? Colors.red[900]
                                    : Colors.grey,
                                fontSize: TextSizing.fontSizeMiniText(context),
                                fontFamily: 'Roboto',
                                fontWeight: selectedCrowdLevel == 2
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: TextSizing.fontSizeHeading(context) * 2),

                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selection == false &&
                          selectedCrowdLevel != -1 &&
                          selectedBusStop != null &&
                          selectedTripNo != null) {
                        _showConfirmationDialog(
                          selectedMRT,
                          selectedTripNo,
                          selectedBusStop,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: TextSizing.fontSizeMiniText(context),
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: TextSizing.fontSizeMiniText(context) * 0.5),
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    onPressed: () {
                      _showNewTripSelectionDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Choose new Trip',
                      style: TextStyle(
                        fontSize: TextSizing.fontSizeMiniText(context),
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: TextSizing.fontSizeHeading(context)),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    formatTimeSecond(now),
                    style: TextStyle(
                      fontSize: TextSizing.fontSizeText(context),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
