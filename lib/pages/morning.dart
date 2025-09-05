import 'dart:async';
import 'dart:convert';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:driver_10_updated/amplifyconfiguration.dart';
import 'package:driver_10_updated/main.dart';
import 'package:driver_10_updated/models/ModelProvider.dart';
import 'package:driver_10_updated/pages/busdata.dart';
import 'package:driver_10_updated/pages/map_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:uuid/uuid.dart';

class Morning_Page extends StatefulWidget {
  const Morning_Page({super.key});

  @override
  State<Morning_Page> createState() => _Morning_PageState();
}

class _Morning_PageState extends State<Morning_Page>
    with WidgetsBindingObserver {
  final ScrollController controller = ScrollController();
  final BusInfo _BusInfo = BusInfo();
  String? selectedMRT;
  int? selectedTripNo;
  String? selectedBusStop;
  int BusStop_Index = 8;
  final int CLE_TripNo = 1;
  final int KAP_TripNo = 1;
  List<String> BusStops = [];
  late Timer _timer;
  Timer? _clocktimer;
  List<DateTime> KAP_DT = [];
  List<DateTime> CLE_DT = [];
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
    BusStops = _BusInfo.BusStop;
    BusStops = BusStops.sublist(2); //sublist used to start from index 2
    selectedBusStop = BusStops[BusStop_Index];
    KAP_DT = _BusInfo.KAPArrivalTime;
    print(KAP_DT);
    CLE_DT = _BusInfo.CLEArrivalTime;

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

  Future<void> create(
    String _MRTStation,
    int _TripNo,
    String _BusStop,
    int _Count,
  ) async {
    try {
      if (_MRTStation == 'KAP') {
        final model = KAPMorning(
          id: Uuid().v4(),
          TripNo: _TripNo,
          BusStop: _BusStop,
          Count: _Count,
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
          TripNo: _TripNo,
          BusStop: _BusStop,
          Count: _Count,
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

  void _showConfirmationDialog(MRT, TripNo, BusStop) {
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
                create(MRT, TripNo, BusStop, count);
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

  void passengerCount(int _count) {
    setState(() {
      count = _count;
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
      return _BusInfo.KAPArrivalTime;
    } else {
      return _BusInfo.CLEArrivalTime;
    }
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

  Widget DrawWidth(double size) {
    return SizedBox(width: MediaQuery.of(context).size.width * size);
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
      now = now!.add(timeUpdateInterval);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (now.hour >= MyApp.screenTime_hour &&
        now.minute >= MyApp.screenTime_min) {
      Future.delayed(Duration.zero, () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Map_Page()),
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
                  DrawLine(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  AddTitle(
                    'Selected Route',
                    MediaQuery.of(context).size.width * 0.08,
                  ),
                  Row(
                    children: [
                      DrawWidth(0.2),
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
                      NormalText(
                        '--   CAMPUS',
                        MediaQuery.of(context).size.width * 0.07,
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
                        child: _selection
                            ? IgnorePointer(
                                ignoring: true, // Disable user interaction
                                child: DropdownButton<int>(
                                  value: selectedTripNo,
                                  items: selectedMRT == 'CLE'
                                      ? _buildTripNoItems(CLE_DT.length)
                                      : selectedMRT == 'KAP'
                                      ? _buildTripNoItems(KAP_DT.length)
                                      : [],
                                  onChanged:
                                      null, // Disable the onChanged function
                                ),
                              )
                            : DropdownButton<int>(
                                value: selectedTripNo,
                                items: selectedMRT == 'CLE'
                                    ? _buildTripNoItems(CLE_DT.length)
                                    : selectedMRT == 'KAP'
                                    ? _buildTripNoItems(KAP_DT.length)
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
                              ? '${formatTime(CLE_DT[selectedTripNo! - 1])}'
                              : '${formatTime(KAP_DT[selectedTripNo! - 1])}',
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
                  DrawLine(),
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
                        '${formatTimesecond(now)}',
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
