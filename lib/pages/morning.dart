import 'dart:async';
import 'dart:convert';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:driver_10_updated/amplifyconfiguration.dart';
import 'package:driver_10_updated/main.dart';
import 'package:driver_10_updated/models/model_provider.dart';
import 'package:driver_10_updated/pages/bus_data.dart';
import 'package:driver_10_updated/pages/map_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:uuid/uuid.dart';

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

  void _showNewTripSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Choose new trip'),
          content: Text('Confirm choose new trip'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog on cancel
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selection = false;
                  selectedCrowdLevel = -1;
                });
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('OK'),
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
          title: Text('Confirmation'),
          content: Text('Confirm Selection'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog on cancel
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selection = true;
                });
                create(mrt, tripNo, busStop, count);
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
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

  void showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        //callback function that returns a widget
        return AlertDialog(
          title: Text('Alert'),
          content: Text('Please select MRT and TripNo.'),
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
            color: Colors.black,
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
      return busInfo.arrivalTimeKAP;
    } else {
      return busInfo.arrivalTimeCLE;
    }
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

  Widget addTitle(String title, double sizeOfFont) {
    return Align(
      alignment: Alignment.center,
      child: Text(
        title,
        style: TextStyle(
          fontSize: sizeOfFont,
          fontWeight: FontWeight.bold,
          fontFamily: 'Timmana',
        ),
      ),
    );
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

  Widget drawWidth(double size) {
    return SizedBox(width: MediaQuery.of(context).size.width * size);
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

  // Future<void> getTime() async {
  //   try {
  //     final uri = Uri.parse('https://worldtimeapi.org/api/timezone/Singapore');
  //     print("Printing URI");
  //     print(uri);
  //     final response = await get(uri);
  //     print("Printing response");
  //     print(response);
  //
  //     // Response response = await get(
  //     //     Uri.parse('https://worldtimeapi.org/api/timezone/Singapore'));
  //     print(response.body);
  //     Map data = jsonDecode(response.body);
  //     print(data);
  //     String datetime = data['datetime'];
  //     String offset = data['utc_offset'].substring(1, 3);
  //     setState(() {
  //       now = DateTime.parse(datetime);
  //       now = now.add(Duration(hours: int.parse(offset)));
  //     });
  //   }
  //   catch (e) {
  //     print('caught error: $e');
  //   }
  // }

  void updateTimeManually() {
    setState(() {
      now = now.add(timeUpdateInterval);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (now.hour >= MyApp.screenTimeHour && now.minute >= MyApp.screenTimeMin) {
      Future.delayed(Duration.zero, () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MapPage()),
        );
      });
    }
    return Scaffold(
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Container(
              color: Colors.lightBlue[100],
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
                        '(Morning)',
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
                      SizedBox(
                        width: 100, // Fixed width for consistency
                        child: _selection
                            ? IgnorePointer(
                                ignoring: true, // Disable user interaction
                                child: DropdownButton<String>(
                                  value: selectedMRT,
                                  items: ['CLE', 'KAP']
                                      .map<DropdownMenuItem<String>>((
                                        String value,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(
                                            value,
                                            style: TextStyle(
                                              fontSize:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width *
                                                  0.06,
                                              fontWeight: FontWeight.w300,
                                              fontFamily: 'NewAmsterdam',
                                              color: Colors.black,
                                            ),
                                          ),
                                        );
                                      })
                                      .toList(),
                                  onChanged:
                                      null, // Disable the onChanged function when selection is active
                                ),
                              )
                            : DropdownButton<String>(
                                value: selectedMRT,
                                items: ['CLE', 'KAP']
                                    .map<DropdownMenuItem<String>>((
                                      String value,
                                    ) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                            fontSize:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.06,
                                            fontWeight: FontWeight.w300,
                                            fontFamily: 'NewAmsterdam',
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedMRT = newValue;
                                    selectedTripNo =
                                        null; // Reset selected trip no when MRT station changes
                                  });
                                },
                              ),
                      ),
                      normalText(
                        '--   CAMPUS',
                        MediaQuery.of(context).size.width * 0.07,
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
                        child: _selection
                            ? IgnorePointer(
                                ignoring: true, // Disable user interaction
                                child: DropdownButton<int>(
                                  value: selectedTripNo,
                                  items: selectedMRT == 'CLE'
                                      ? _buildTripNoItems(dateTimeCLE.length)
                                      : selectedMRT == 'KAP'
                                      ? _buildTripNoItems(dateTimeKAP.length)
                                      : [],
                                  onChanged:
                                      null, // Disable the onChanged function
                                ),
                              )
                            : DropdownButton<int>(
                                value: selectedTripNo,
                                items: selectedMRT == 'CLE'
                                    ? _buildTripNoItems(dateTimeCLE.length)
                                    : selectedMRT == 'KAP'
                                    ? _buildTripNoItems(dateTimeKAP.length)
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
                              ? formatTime(dateTimeCLE[selectedTripNo! - 1])
                              : formatTime(dateTimeKAP[selectedTripNo! - 1]),
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.06,
                            fontWeight: FontWeight.w300,
                            fontFamily: 'NewAmsterdam',
                            color: Colors.black,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  drawLine(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  // Inside the build method
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
                                ? Colors.green[100]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedCrowdLevel == 0
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Icon(
                                Icons.sentiment_satisfied,
                                color: selectedCrowdLevel == 0
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 5),
                              const Text('< half'),
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
                                ? Colors.orange[100]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedCrowdLevel == 1
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Icon(
                                Icons.sentiment_neutral,
                                color: selectedCrowdLevel == 1
                                    ? Colors.orange
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 5),
                              const Text('>= half'),
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
                                ? Colors.red[100]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedCrowdLevel == 2
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Icon(
                                Icons.sentiment_dissatisfied,
                                color: selectedCrowdLevel == 2
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 5),
                              const Text('Full'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 15, 0),
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

                        child: Text('Confirm'),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 15, 0),
                      child: ElevatedButton(
                        onPressed: () {
                          _showNewTripSelectionDialog();
                        },
                        child: Text('Choose New Trip'),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 15, 0),
                      child: Text(
                        formatTimesecond(now),
                        style: TextStyle(
                          fontFamily: 'Tomorrow',
                          fontSize: MediaQuery.of(context).size.width * 0.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
