import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:driver_10_updated/models/ModelProvider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

import '../utils/get_data.dart';
import '../utils/text_sizing.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- Afternoon Page ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// AfternoonPage class

class AfternoonPage extends StatefulWidget {
  const AfternoonPage({super.key});

  @override
  State<AfternoonPage> createState() => _AfternoonPageState();
}

class _AfternoonPageState extends State<AfternoonPage>
    with WidgetsBindingObserver {
  //////////////////////////////////////////////////////////////////////////////
  // Variables

  // Local bus data helper
  final BusData _busData = BusData();

  // add listener token
  VoidCallback? _busDataListener;

  // Time now, to generate background colour later
  DateTime now = DateTime.now();

  // To increment time for colour change
  Timer? _clockTimer;

  // update and fetch intervals
  Duration timeUpdateInterval = Duration(seconds: 1);
  Duration apiFetchInterval = Duration(minutes: 1);

  // amount of time that has passed since last fetch
  int secondsElapsed = 0;

  // To save all the necessary variables locally
  List<DateTime> afternoonTripsKAP = [];
  List<DateTime> afternoonTripsCLE = [];
  List<String> busStops = [];

  // Currently selected MRT
  String? selectedMRT;

  // Which Trip No is selected
  int? selectedTripNo;

  // Which BusStop is selected
  String? selectedBusStop;

  // For Passenger Count
  int? passengerCountTrip;
  int? passengerCountAtBusStop;
  int maxPassengersCount = 30;

  // Whether a crowd level has been selected, and if which one
  bool _selection = false;

  // As a guard to prevent buttons being pressed to quickly
  bool buttonPressed = false;

  // used to pass on count, will be assigned one of the values from above
  int count = 0;

  // for sizing
  double fontSizeMiniText = 0;
  double fontSizeText = 0;
  double fontSizeHeading = 0;

  //////////////////////////////////////////////////////////////////////////////
  // Init function (called when first built)
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    afternoonTripsKAP = _busData.afternoonTimesKAP;
    afternoonTripsCLE = _busData.afternoonTimesCLE;
    busStops = _busData.busStop;

    if (kDebugMode) {
      print('afternoon screen initState');
    }

    if (_busDataListener != null) {
      _busData.removeListener(_busDataListener!);
    }

    // Make the listener a synchronous VoidCallback that spawns an async task
    _busDataListener = () async {
      if (kDebugMode) print('BusDataListener called, _busData was refreshed');
      if (selectedMRT != null && selectedTripNo != null) {
        passengerCountTrip = await fetchPassengerCountTrip(
          station: selectedMRT!,
          tripNo: selectedTripNo!,
        );

        if (selectedBusStop != null) {
          passengerCountAtBusStop = await fetchBusStopPassengerCount(
            station: selectedMRT!,
            tripNo: selectedTripNo!,
            busStop: selectedBusStop!,
          );
        }
      }
      setState(() {
        afternoonTripsKAP = _busData.afternoonTimesKAP;
        afternoonTripsCLE = _busData.afternoonTimesCLE;
        busStops = _busData.busStop;
        passengerCountTrip;
        passengerCountAtBusStop;
      });
    };
    _busData.addListener(_busDataListener!);

    // Schedule periodic refresh of timer, so that background colour changes accordingly
    getTime().then((_) {
      _clockTimer = Timer.periodic(timeUpdateInterval, (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        // Increment local time representation synchronously
        updateTimeManually();
        secondsElapsed += timeUpdateInterval.inSeconds;

        // Every [apiFetchInterval], refresh the time from the API as a fire-and-forget Future.
        if (secondsElapsed >= apiFetchInterval.inSeconds) {
          secondsElapsed = 0;
        }
      });
    });
  }

  //////////////////////////////////////////////////////////////////////////////
  // function called at start (after initState)
  // to determine sizing variables

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // assign sizing variables once at start
    fontSizeMiniText = TextSizing.fontSizeMiniText(context);
    fontSizeText = TextSizing.fontSizeText(context);
    fontSizeHeading = TextSizing.fontSizeHeading(context);
  }

  //////////////////////////////////////////////////////////////////////////////
  // when app is closed and reopened from background

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        print('app resumed, refetching time');
      }
      // The app is resumed; re-fetch the time from the API
      getTime();
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // dispose function (called when build is destroyed)

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_busDataListener != null) {
      _busData.removeListener(_busDataListener!);
      _busDataListener = null;
    }
    _clockTimer?.cancel();
    super.dispose();
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- updates count ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Updates the passenger count for a specific trip and bus stop.
  // If a count record exists, it is deleted and replaced with the new count.
  // If no bookings remain, no new record is created.
  // true => successfully updated
  // false => invalid range (count < 0 or > maxPassengerCount)
  // null => error

  Future<bool?> _updateCount({
    required bool isKAP,
    required int tripNo,
    required String busStop,
    required bool increment, // true = +1, false = -1
  }) async {
    final station = isKAP ? 'KAP' : 'CLE';

    // variables to later check if new value ok
    int newPassengerCountOfTrip = 0;
    int newPassengerCountAtBusStop = 0;
    if (passengerCountTrip != null) {
      newPassengerCountOfTrip = passengerCountTrip! + (increment ? 1 : -1);
    }
    if (passengerCountAtBusStop != null) {
      newPassengerCountAtBusStop =
          passengerCountAtBusStop! + (increment ? 1 : -1);
    }

    if (newPassengerCountOfTrip > 30 ||
        newPassengerCountOfTrip < 0 ||
        newPassengerCountAtBusStop < 0) {
      if (kDebugMode) {
        print(
          'newPassengerCountOfTrip: $newPassengerCountOfTrip or newPassengerCountAtBusStop $newPassengerCountAtBusStop in invalid range, therefore did not update count',
        );
      }
      return false;
    }
    try {
      // Step 1: Query existing CountTripList entries for this station/trip/busStop
      final existingResponse = await Amplify.API
          .query(
            request: ModelQueries.list(
              CountTripList.classType,
              where: CountTripList.MRTSTATION
                  .eq(station)
                  .and(CountTripList.TRIPTIME.eq(TripTimeOfDay.AFTERNOON))
                  .and(CountTripList.TRIPNO.eq(tripNo))
                  .and(CountTripList.BUSSTOP.eq(busStop)),
              authorizationMode: APIAuthorizationType.iam,
            ),
          )
          .response;

      final items = existingResponse.data?.items.cast<CountTripList>() ?? [];

      // Step 1a: filter by createdAt → only keep rows created today (Singapore time)
      final nowLocal = DateTime.now();
      final todayDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

      final todayRows = items.where((row) {
        final createdUtc = row.createdAt?.getDateTimeInUtc();
        if (createdUtc == null) return false;

        // Convert UTC → local (SGT if device timezone is Singapore)
        final createdLocal = createdUtc.toLocal();
        final createdDate = DateTime(
          createdLocal.year,
          createdLocal.month,
          createdLocal.day,
        );

        // Compare only the date parts
        return createdDate == todayDate;
      }).toList();

      final existingRow = todayRows.isNotEmpty ? todayRows.first : null;

      if (existingRow != null) {
        // Step 2: Update existing row
        final newCount = (existingRow.Count) + (increment ? 1 : -1);

        if (newCount < 0) {
          if (kDebugMode) {
            print('No count changed, as newCount in invalid range');
          }
        } else {
          final updatedRow = existingRow.copyWith(Count: newCount);
          await Amplify.API
              .mutate(
                request: ModelMutations.update(
                  updatedRow,
                  authorizationMode: APIAuthorizationType.iam,
                ),
              )
              .response;
          if (kDebugMode) print('Updated count → $newCount');
        }
      } else {
        // Step 3: Create new row if none exists for today
        final model = CountTripList(
          MRTStation: station,
          TripTime: TripTimeOfDay.AFTERNOON,
          BusStop: busStop,
          TripNo: tripNo,
          Count: increment ? 1 : 0,
        );

        if (model.Count > 0) {
          await Amplify.API
              .mutate(
                request: ModelMutations.create(
                  model,
                  authorizationMode: APIAuthorizationType.iam,
                ),
              )
              .response;
          if (kDebugMode) print('Created new CountTripList with count=1');
        }
      }
      return true;
    } catch (e, st) {
      if (kDebugMode) print('Error updating count: $e\n$st');
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Counts the number of bookings for a given MRT station and trip number
  // Returns the count as an integer, or 0 if an error occurs

  Future<int> fetchPassengerCountTrip({
    required String station,
    required int tripNo,
  }) async {
    const tripTime = 'AFTERNOON';
    try {
      final request = GraphQLRequest<String>(
        document: '''
        query GetTripCounts(\$station: String!, \$tripTime: TripTimeOfDay!, \$tripNo: Int!) {
          listCountTripLists(
            filter: {
              MRTStation: { eq: \$station }
              TripTime: { eq: \$tripTime }
              TripNo: { eq: \$tripNo }
            }
          ) {
            items {
              Count
              createdAt
            }
          }
        }
      ''',
        variables: {'station': station, 'tripTime': tripTime, 'tripNo': tripNo},
      );

      final response = await Amplify.API.query(request: request).response;
      final data = response.data;
      if (data == null) return 0;

      final items = (jsonDecode(data)['listCountTripLists']['items'] as List);

      if (items.isEmpty) return 0;

      // Singapore local time (system timezone should be set to SGT)
      final nowLocal = DateTime.now();
      final todayDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

      final todayItems = items.where((item) {
        final createdStr = item['createdAt'];
        if (createdStr == null) return false;

        final createdUtc = DateTime.tryParse(createdStr);
        if (createdUtc == null) return false;

        // Convert UTC → local (SGT if system timezone is Singapore)
        final createdLocal = createdUtc.toLocal();
        final createdDate = DateTime(
          createdLocal.year,
          createdLocal.month,
          createdLocal.day,
        );

        // Compare only the date parts
        return createdDate == todayDate;
      }).toList();

      return todayItems.fold<int>(
        0,
        (sum, item) => sum + (item['Count'] as int),
      );
    } catch (e) {
      safePrint('Error fetching passenger count: $e');
      return 0;
    }
  }

  /////////////////////////////////////////////////////////////////////////////
  // Gets the number of bookings at a selected bus stop (with TripNo and MRT)
  // returns 0 if no entries are found

  Future<int> fetchBusStopPassengerCount({
    required String station,
    required int tripNo,
    required String busStop,
  }) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
        query GetBusStopCount(\$station: String!, \$tripNo: Int!, \$busStop: String!) {
          listCountTripLists(
            filter: {
              MRTStation: { eq: \$station }
              TripNo: { eq: \$tripNo }
              BusStop: { eq: \$busStop }
            }
          ) {
            items {
              Count
              createdAt
            }
          }
        }
      ''',
        variables: {'station': station, 'tripNo': tripNo, 'busStop': busStop},
      );

      final response = await Amplify.API.query(request: request).response;
      final data = response.data;
      if (data == null) return 0;

      final items = (jsonDecode(data)['listCountTripLists']['items'] as List);
      if (items.isEmpty) return 0;

      // Singapore local time (system timezone should be set to SGT)
      final nowLocal = DateTime.now();
      final todayDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

      final todayItems = items.where((item) {
        final createdStr = item['createdAt'];
        if (createdStr == null) return false;

        final createdUtc = DateTime.tryParse(createdStr);
        if (createdUtc == null) return false;

        // Convert UTC → local (SGT if system timezone is Singapore)
        final createdLocal = createdUtc.toLocal();
        final createdDate = DateTime(
          createdLocal.year,
          createdLocal.month,
          createdLocal.day,
        );

        // Compare only the date parts
        return createdDate == todayDate;
      }).toList();

      // If you want the **sum** of counts for today:
      return todayItems.fold<int>(
        0,
        (sum, item) => sum + (item['Count'] as int),
      );

      // If you only want the **first** matching count for today:
      // return todayItems.isEmpty ? 0 : todayItems.first['Count'] as int;
    } catch (e) {
      safePrint('Error fetching bus stop passenger count: $e');
      return 0;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Alert Dialogs ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // when trying to select Crowd level but no MRT or trip is selected

  void _showPleaseSelectTripAndBusStopDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        //callback function that returns a widget
        return AlertDialog(
          actionsAlignment: MainAxisAlignment.center,
          title: Center(
            child: Text(
              'Alert',
              style: TextStyle(
                fontSize: fontSizeHeading,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: Text(
            'Please select an MRT Station, and Trip Number before proceeding.',
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontSize: fontSizeMiniText,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.normal,
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: Container(
                padding: EdgeInsetsGeometry.all(fontSizeText * 0.1),
                child: Text(
                  'OK',
                  style: TextStyle(
                    fontSize: fontSizeMiniText,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- changing background colour ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // generated colours, will be used as background colour and to check tickets?

  Color? generateColor(List<DateTime> dt, int selectedTripNo) {
    if (selectedTripNo <= 0 || selectedTripNo > dt.length) return null;

    final List<Color?> colors = [
      Colors.red[100],
      Colors.red[200],
      Colors.orange[200],
      Colors.orange[100],
      Colors.yellow[200],
      Colors.green[200],
      Colors.blue[200],
      Colors.indigo[100],
      Colors.deepPurple[200],
      Colors.purple[200],
    ];

    final DateTime departureTime = dt[selectedTripNo - 1];

    // Seconds since midnight for both times.
    final int departureSeconds =
        departureTime.hour * 3600 +
        departureTime.minute * 60 +
        departureTime.second;

    final int nowSeconds = now.hour * 3600 + now.minute * 60 + now.second;

    // Day index: number of days since epoch to ensure day-to-day variation.
    final int dayIndex =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        (1000 * 60 * 60 * 24);

    // Combine components; bucket by 10 seconds for coarse stability.
    final int combined =
        (departureSeconds + nowSeconds + dayIndex) & 0x7fffffff;
    final int seed = combined ~/ 10;

    final Random random = Random(seed);
    final int index = random.nextInt(colors.length);

    return colors[index];
  }

  //////////////////////////////////////////////////////////////////////////////
  // get Time

  Future<void> getTime() async {
    DateTime? timeNow;
    try {
      // API endpoint for Singapore time (timeapi.io)
      final uri = Uri.parse(
        'https://www.timeapi.io/api/time/current/zone?timeZone=ASIA%2FSINGAPORE',
      );
      // Alternative API (commented out):
      // final uri = Uri.parse('https://worldtimeapi.org/api/timezone/Singapore');

      // Make GET request to the API
      final response = await get(uri);

      if (kDebugMode) {
        print("Printing response: $response");
      }

      // If request was successful
      if (response.statusCode == 200) {
        // Decode JSON response into a Map
        Map<String, dynamic> data = jsonDecode(response.body);

        // Extract the datetime string (timeapi.io uses 'dateTime' key)
        String datetime = data['dateTime'];

        // Parse the datetime string into a DateTime object
        timeNow = DateTime.parse(datetime);

        if (kDebugMode) {
          print("Updated Time: $timeNow");
        }

        setState(() {
          now = timeNow!;
        });
        return;
      } else {
        // If request failed, log the status code
        if (kDebugMode) {
          print(
            "Failed to get time data from the API. Status Code: ${response.statusCode}",
          );
        }
      }
    } catch (e) {
      // Catch and log any errors during the request or parsing
      if (kDebugMode) {
        print('Caught error1: $e');
      }
    }
    // fallback to device local UTC time zone and convert to singapore time zone

    if (kDebugMode) {
      print('timeNow could not be fetched, falling back to device time');
    }
    // Get the current device time
    DateTime localTime = DateTime.now();
    // Convert local time to UTC
    DateTime utcTime = localTime.toUtc();

    setState(() {
      now = utcTime.add(Duration(hours: 8));
    });

    return;
  }

  void updateTimeManually() {
    if (mounted) {
      setState(() {
        now = now.add(timeUpdateInterval);
      });
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Format ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Draws a horizontal black Line

  Widget drawLine() {
    return Column(
      children: [
        Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: fontSizeMiniText * 0.1,
          color: Colors.black,
        ),
      ],
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  // formats time nicely for display

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

  List<String> buildBusStopItems(String? selectedMRT, List<String> busStops) {
    if (busStops.length < 4) return [];

    if (selectedMRT == 'CLE') {
      return List<String>.generate(busStops.length - 3, (i) => busStops[i + 2]);
    } else if (selectedMRT == 'KAP') {
      return List<String>.generate(busStops.length - 3, (i) => busStops[i + 2]);
    }
    return [];
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Main Build ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: fontSizeText),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'SELECT ROUTE',
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSizeText,
                          fontWeight: FontWeight.normal,
                          color: Colors.black,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),

                    SizedBox(width: fontSizeText),

                    Text(
                      'CAMPUS - ',
                      style: TextStyle(
                        fontSize: fontSizeText,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'Roboto',
                      ),
                    ),

                    Container(
                      color: Colors.black,
                      child: DropdownButton<String>(
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(fontSizeMiniText * 0.2),
                        style: TextStyle(color: Colors.white), //  text color
                        dropdownColor: Colors.black, //  menu background
                        iconEnabledColor: Colors.white, //  arrow color
                        focusColor: Colors.black,
                        value: selectedMRT,
                        items: ['KAP', 'CLE'].map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Center(
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontSize: fontSizeText,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedMRT = newValue;
                            // Reset all variables when selecting a different MRT station
                            selectedTripNo = null;
                            selectedBusStop = null;
                            passengerCountTrip = null;
                            passengerCountAtBusStop = null;
                            _selection = false;
                          });
                        },
                        underline: SizedBox(),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: fontSizeText),
                drawLine(),

                Container(
                  color: (selectedTripNo != null)
                      ? generateColor(
                          selectedMRT == 'KAP'
                              ? afternoonTripsKAP
                              : afternoonTripsCLE,
                          selectedTripNo!,
                        )
                      : Colors.white,

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: fontSizeText),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                child: Text(
                                  'TRIP NUMBER',
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: fontSizeText,
                                    fontWeight: FontWeight.normal,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                              SizedBox(height: fontSizeMiniText * 0.5),
                              SizedBox(
                                height: fontSizeHeading * 1.5,
                                width: fontSizeHeading * 2,
                                child: Center(
                                  child: Container(
                                    color: Colors.black,

                                    child: _selection
                                        ? IgnorePointer(
                                            ignoring:
                                                true, // Disable user interaction
                                            child: DropdownButton<int>(
                                              alignment: Alignment.center,
                                              padding: EdgeInsets.all(
                                                fontSizeMiniText * 0.2,
                                              ),
                                              value: selectedTripNo,
                                              isExpanded: true,
                                              dropdownColor: Colors.black,
                                              iconEnabledColor: Colors.white,
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                              items:
                                                  (selectedMRT == 'CLE'
                                                          ? List<int>.generate(
                                                              afternoonTripsCLE
                                                                  .length,
                                                              (i) => i + 1,
                                                            )
                                                          : selectedMRT == 'KAP'
                                                          ? List<int>.generate(
                                                              afternoonTripsKAP
                                                                  .length,
                                                              (i) => i + 1,
                                                            )
                                                          : [])
                                                      .map<
                                                        DropdownMenuItem<int>
                                                      >((value) {
                                                        final int tripNo =
                                                            value
                                                                as int; // cast dynamic → int

                                                        return DropdownMenuItem<
                                                          int
                                                        >(
                                                          value: tripNo,
                                                          child: Center(
                                                            child: Text(
                                                              tripNo.toString(),
                                                              style: TextStyle(
                                                                fontSize:
                                                                    fontSizeText,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontFamily:
                                                                    'Roboto',
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      })
                                                      .toList(),
                                              onChanged: null, // Disabled
                                              underline: SizedBox(),
                                            ),
                                          )
                                        : DropdownButton<int>(
                                            alignment: Alignment.center,
                                            padding: EdgeInsets.all(
                                              fontSizeMiniText * 0.2,
                                            ),
                                            value: selectedTripNo,
                                            isExpanded: true,
                                            dropdownColor: Colors.black,
                                            iconEnabledColor: Colors.white,
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                            items:
                                                (selectedMRT == 'CLE'
                                                        ? List<int>.generate(
                                                            afternoonTripsCLE
                                                                .length,
                                                            (i) => i + 1,
                                                          )
                                                        : selectedMRT == 'KAP'
                                                        ? List<int>.generate(
                                                            afternoonTripsKAP
                                                                .length,
                                                            (i) => i + 1,
                                                          )
                                                        : [])
                                                    .map<
                                                      DropdownMenuItem<int>
                                                    >((value) {
                                                      final int tripNo =
                                                          value
                                                              as int; // cast dynamic → int
                                                      return DropdownMenuItem<
                                                        int
                                                      >(
                                                        value: tripNo,
                                                        child: Center(
                                                          child: Text(
                                                            tripNo.toString(),
                                                            style: TextStyle(
                                                              fontSize:
                                                                  fontSizeText,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontFamily:
                                                                  'Roboto',
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    })
                                                    .toList(),
                                            onChanged: (int? newValue) async {
                                              if (selectedMRT != null &&
                                                  newValue != null) {
                                                passengerCountTrip =
                                                    await fetchPassengerCountTrip(
                                                      station: selectedMRT!,
                                                      tripNo: newValue,
                                                    );
                                              } else {
                                                passengerCountTrip = null;
                                              }
                                              setState(() {
                                                selectedTripNo = newValue;
                                                passengerCountTrip;
                                                passengerCountAtBusStop = null;
                                                selectedBusStop = null;
                                                // reset selection
                                                _selection = false;
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
                                      fontSize: fontSizeText,
                                      fontWeight: FontWeight.normal,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: fontSizeMiniText * 0.5),
                              if (selectedMRT != null && selectedTripNo != null)
                                SizedBox(
                                  height: fontSizeHeading * 1.5,
                                  child: Center(
                                    child: Text(
                                      selectedMRT == 'CLE'
                                          ? formatTime(
                                              afternoonTripsCLE[selectedTripNo! -
                                                  1],
                                            )
                                          : formatTime(
                                              afternoonTripsKAP[selectedTripNo! -
                                                  1],
                                            ),
                                      style: TextStyle(
                                        fontSize: fontSizeText,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Roboto',
                                      ),
                                    ),
                                  ),
                                ),
                              if (!(selectedMRT != null &&
                                  selectedTripNo != null))
                                SizedBox(
                                  width: fontSizeHeading * 2,
                                  height: fontSizeHeading * 1.5,
                                  child: Center(
                                    child: Text(
                                      '--:--',
                                      style: TextStyle(
                                        fontSize: fontSizeText,
                                        fontWeight: FontWeight.normal,
                                        fontFamily: 'Roboto',
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: fontSizeText),
                    ],
                  ),
                ),

                drawLine(),
                SizedBox(height: fontSizeText),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: fontSizeHeading * 1.5,
                            child: Align(
                              alignment: Alignment
                                  .centerLeft, // places at start (left) but vertically centered

                              child: Text(
                                'TOTAL BOOKINGS',
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: fontSizeText,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.black,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: fontSizeHeading * 1.5,
                            child: Align(
                              alignment: Alignment
                                  .centerLeft, // places at start (left) but vertically centered

                              child: Text(
                                'VACANCY',
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: fontSizeText,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.black,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            height: fontSizeHeading * 1.5,
                            child: Align(
                              alignment: Alignment
                                  .centerLeft, // places at start (left) but vertically centered

                              child: Text(
                                'SELECT BUS STOP',
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: fontSizeText,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.black,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            height: fontSizeHeading * 1.5,
                            child: Align(
                              alignment: Alignment
                                  .centerLeft, // places at start (left) but vertically centered

                              child: Text(
                                'BOOKINGS AT BUS STOP',
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: fontSizeText,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.black,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: fontSizeText),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: fontSizeHeading * 1.5,
                          width: fontSizeHeading * 3,
                          child: Center(
                            child: Text(
                              passengerCountTrip == null
                                  ? ' - '
                                  : '$passengerCountTrip',
                              style: TextStyle(
                                fontSize: fontSizeText,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: fontSizeHeading * 1.5,
                          width: fontSizeHeading * 3,
                          child: Center(
                            child: Text(
                              passengerCountTrip == null
                                  ? ' - '
                                  : '${maxPassengersCount - passengerCountTrip!}',
                              style: TextStyle(
                                fontSize: fontSizeText,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            // Left button
                            IconButton(
                              icon: Icon(
                                Icons.arrow_left,
                                color: Colors.black,
                                size: fontSizeHeading,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                if (selectedBusStop != null &&
                                    busStops.length > 3) {
                                  final currentIndex = busStops.indexOf(
                                    selectedBusStop!,
                                  );

                                  if (currentIndex >= 0) {
                                    var newIndex =
                                        (currentIndex - 1 + busStops.length) %
                                        busStops.length;

                                    // keep moving left until we’re not in the first two or last entry
                                    while (newIndex <= 1 ||
                                        newIndex == busStops.length - 1) {
                                      newIndex =
                                          (newIndex - 1 + busStops.length) %
                                          busStops.length;
                                    }

                                    final newValue = busStops[newIndex];

                                    passengerCountAtBusStop =
                                        await fetchBusStopPassengerCount(
                                          station: selectedMRT!,
                                          tripNo: selectedTripNo!,
                                          busStop: newValue,
                                        );

                                    setState(() {
                                      selectedBusStop = newValue;
                                    });
                                  }
                                }
                              },
                            ),

                            SizedBox(
                              height: fontSizeHeading * 1.5,
                              width: fontSizeHeading * 2.75,
                              child: Center(
                                child: Container(
                                  color: Colors.black,

                                  child: (_selection || selectedTripNo == null)
                                      ? IgnorePointer(
                                          ignoring: true,
                                          child: DropdownButton<String>(
                                            alignment: Alignment.center,
                                            padding: EdgeInsets.all(
                                              fontSizeMiniText * 0.2,
                                            ),
                                            value: selectedBusStop,
                                            isExpanded: true,
                                            dropdownColor: Colors.black,
                                            iconEnabledColor: Colors.white,
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                            items:
                                                buildBusStopItems(
                                                  selectedMRT,
                                                  busStops,
                                                ).map<DropdownMenuItem<String>>(
                                                  (value) {
                                                    return DropdownMenuItem<
                                                      String
                                                    >(
                                                      value: value,
                                                      child: Center(
                                                        child: Text(
                                                          value,
                                                          style: TextStyle(
                                                            fontSize:
                                                                fontSizeText,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontFamily:
                                                                'Roboto',
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ).toList(),
                                            onChanged: null,
                                            underline: SizedBox(),
                                          ),
                                        )
                                      : DropdownButton<String>(
                                          alignment: Alignment.center,
                                          padding: EdgeInsets.all(
                                            fontSizeMiniText * 0.2,
                                          ),
                                          value: selectedBusStop,
                                          isExpanded: true,
                                          dropdownColor: Colors.black,
                                          iconEnabledColor: Colors.white,
                                          style: TextStyle(color: Colors.white),
                                          items:
                                              buildBusStopItems(
                                                selectedMRT,
                                                busStops,
                                              ).map<DropdownMenuItem<String>>((
                                                value,
                                              ) {
                                                return DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Center(
                                                    child: Text(
                                                      value,
                                                      style: TextStyle(
                                                        fontSize: fontSizeText,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontFamily: 'Roboto',
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                          onChanged: (String? newValue) async {
                                            if (selectedMRT != null &&
                                                selectedTripNo != null &&
                                                newValue != null) {
                                              passengerCountAtBusStop =
                                                  await fetchBusStopPassengerCount(
                                                    station: selectedMRT!,
                                                    tripNo: selectedTripNo!,
                                                    busStop: newValue,
                                                  );
                                            } else {
                                              passengerCountAtBusStop = null;
                                            }
                                            setState(() {
                                              selectedBusStop = newValue;
                                            });
                                          },
                                          underline: SizedBox(),
                                        ),
                                ),
                              ),
                            ), // Right button
                            IconButton(
                              icon: Icon(
                                Icons.arrow_right,
                                color: Colors.black,
                                size: fontSizeHeading,
                              ),
                              padding: EdgeInsets
                                  .zero, // use EdgeInsets.zero instead of EdgeInsetsGeometry.all(0)
                              onPressed: () async {
                                if (selectedBusStop != null &&
                                    busStops.length > 3) {
                                  final currentIndex = busStops.indexOf(
                                    selectedBusStop!,
                                  );

                                  if (currentIndex >= 0) {
                                    var newIndex =
                                        (currentIndex + 1) % busStops.length;

                                    // keep moving right until we’re not in the first two or last entry
                                    while (newIndex <= 1 ||
                                        newIndex == busStops.length - 1) {
                                      newIndex =
                                          (newIndex + 1) % busStops.length;
                                    }

                                    final newValue = busStops[newIndex];

                                    passengerCountAtBusStop =
                                        await fetchBusStopPassengerCount(
                                          station: selectedMRT!,
                                          tripNo: selectedTripNo!,
                                          busStop: newValue,
                                        );

                                    setState(() {
                                      selectedBusStop = newValue;
                                    });
                                  }
                                }
                              },
                            ),
                          ],
                        ),

                        SizedBox(
                          height: fontSizeHeading * 1.5,
                          width: fontSizeHeading * 3,
                          child: Center(
                            child: Text(
                              passengerCountAtBusStop == null
                                  ? ' - '
                                  : '$passengerCountAtBusStop',
                              style: TextStyle(
                                fontSize: fontSizeText,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: fontSizeText),
                drawLine(),
                SizedBox(height: fontSizeText),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'EDIT BOOKING COUNT',
                        maxLines: 1, //  limits to 1 lines
                        overflow:
                            TextOverflow.ellipsis, // clips text if not fitting
                        style: TextStyle(
                          fontSize: fontSizeText,
                          fontWeight: FontWeight.normal,
                          color: Colors.black,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),

                    SizedBox(width: fontSizeText),

                    ElevatedButton(
                      onPressed: () async {
                        if (buttonPressed == true) {
                          if (kDebugMode) {
                            print(
                              'button pressed to quickly, waiting for a different button press to finish',
                            );
                          }
                        } else {
                          buttonPressed = true;
                          if (selectedMRT != null &&
                              selectedTripNo != null &&
                              selectedBusStop != null) {
                            bool? didUpdate = await _updateCount(
                              isKAP: selectedMRT! == 'KAP',
                              tripNo: selectedTripNo!,
                              busStop: selectedBusStop!,
                              increment: true,
                            );

                            if (didUpdate == true && mounted) {
                              int newPassengerCount = passengerCountTrip! + 1;
                              int newPassengerCountAtBusStop =
                                  passengerCountAtBusStop! + 1;
                              if (kDebugMode) {
                                print(
                                  'Passenger Count of Trip $selectedTripNo $selectedMRT updated to $newPassengerCount, at Bus Stop $selectedBusStop to $newPassengerCountAtBusStop',
                                );
                              }
                              setState(() {
                                passengerCountTrip = newPassengerCount;
                                passengerCountAtBusStop =
                                    newPassengerCountAtBusStop;
                                buttonPressed = false;
                              });
                            } else {
                              setState(() {
                                buttonPressed = false;
                              });
                            }
                          } else {
                            _showPleaseSelectTripAndBusStopDialog(context);
                            setState(() {
                              buttonPressed = false;
                            });
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.green[200],
                        padding: EdgeInsets.all(
                          TextSizing.fontSizeMiniText(context) * 0.3,
                        ),
                        shape: const CircleBorder(),
                      ),

                      child: Icon(
                        Icons.add_circle,
                        size: TextSizing.fontSizeText(context) * 1.5,
                      ),
                    ),

                    SizedBox(width: fontSizeMiniText * 0.5),

                    ElevatedButton(
                      onPressed: () async {
                        if (buttonPressed == true) {
                          if (kDebugMode) {
                            print(
                              'button pressed to quickly, waiting for a different button press to finish',
                            );
                          }
                        } else {
                          buttonPressed = true;
                          if (selectedMRT != null &&
                              selectedTripNo != null &&
                              selectedBusStop != null) {
                            bool? didUpdate = await _updateCount(
                              isKAP: selectedMRT! == 'KAP',
                              tripNo: selectedTripNo!,
                              busStop: selectedBusStop!,
                              increment: false,
                            );

                            if (didUpdate == true && mounted) {
                              int newPassengerCount = passengerCountTrip! - 1;
                              int newPassengerCountAtBusStop =
                                  passengerCountAtBusStop! - 1;
                              if (kDebugMode) {
                                print(
                                  'Passenger Count of Trip $selectedTripNo $selectedMRT updated to $newPassengerCount, at Bus Stop $selectedBusStop to $newPassengerCountAtBusStop',
                                );
                              }
                              setState(() {
                                passengerCountTrip = newPassengerCount;
                                passengerCountAtBusStop =
                                    newPassengerCountAtBusStop;
                                buttonPressed = false;
                              });
                            } else {
                              setState(() {
                                buttonPressed = false;
                              });
                            }
                          } else {
                            _showPleaseSelectTripAndBusStopDialog(context);
                            setState(() {
                              buttonPressed = false;
                            });
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.red[200],
                        padding: EdgeInsets.all(
                          TextSizing.fontSizeMiniText(context) * 0.3,
                        ),
                        shape: const CircleBorder(),
                      ),
                      child: Icon(
                        Icons.remove_circle,
                        size: TextSizing.fontSizeText(context) * 1.5,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: fontSizeHeading),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
