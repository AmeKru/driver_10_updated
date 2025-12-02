import 'dart:async';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:driver_10_updated/models/ModelProvider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/get_data.dart';
import '../utils/text_sizing.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- Morning Page ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// MorningPage class

class MorningPage extends StatefulWidget {
  const MorningPage({super.key});

  @override
  State<MorningPage> createState() => _MorningPageState();
}

class _MorningPageState extends State<MorningPage> with WidgetsBindingObserver {
  //////////////////////////////////////////////////////////////////////////////
  // Variables

  // Local bus data helper
  final BusData _busData = BusData();

  // guard when loading
  bool loading = false;

  // add listener token
  VoidCallback? _busDataListener;

  // To save all the necessary variables locally
  List<DateTime> morningTripsKAP = [];
  List<DateTime> morningTripsCLE = [];

  // Currently selected MRT
  String? selectedMRT;

  // Which Trip No is selected
  int? selectedTripNo;

  // Whether a crowd level has been selected, and if which one
  bool _selection = false;
  int selectedCrowdLevel = -1;

  // Rough estimate for passenger count when selecting a button
  final int lessThanHalfFullCount = 6;
  final int moreOrHalfFullCount = 18;
  final int fullCount = 30;
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

    morningTripsKAP = _busData.morningTimesKAP;
    morningTripsCLE = _busData.morningTimesCLE;

    if (kDebugMode) {
      print('morning screen initState');
    }

    if (_busDataListener != null) {
      _busData.removeListener(_busDataListener!);
    }

    // Make the listener a synchronous VoidCallback that spawns an async task
    _busDataListener = () {
      if (kDebugMode) print('BusDataListener called, _busData was refreshed');
      setState(() {
        morningTripsKAP = _busData.morningTimesKAP;
        morningTripsCLE = _busData.morningTimesCLE;
      });
    };
    _busData.addListener(_busDataListener!);
    if (kDebugMode) {}
  }

  //////////////////////////////////////////////////////////////////////////////
  // function called at start (after initState or similar)
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
  // dispose function (called when build is destroyed)

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_busDataListener != null) {
      _busData.removeListener(_busDataListener!);
      _busDataListener = null;
    }
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

  Future<void> _updateCount({
    required bool isKAP,
    required int tripNo,
    required String busStop,
    required int passengerCount,
  }) async {
    final station = isKAP ? 'KAP' : 'CLE';

    try {
      // Step 1: Query existing CountTripList entries
      final existingResponse = await Amplify.API
          .query(
            request: ModelQueries.list(
              CountTripList.classType,
              where: CountTripList.MRTSTATION
                  .eq(station)
                  .and(CountTripList.TRIPTIME.eq(TripTimeOfDay.MORNING))
                  .and(CountTripList.TRIPNO.eq(tripNo))
                  .and(CountTripList.BUSSTOP.eq(busStop)),
              authorizationMode: APIAuthorizationType.iam,
            ),
          )
          .response;

      final items = existingResponse.data?.items.cast<CountTripList>() ?? [];

      // Step 1a: filter by createdAt → only rows created today (Singapore time)
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
        final newCount = passengerCount;

        if (newCount <= 0) {
          if (kDebugMode) {
            print('No count changed, as newCount in invalid range');
          }
        } else {
          // update with new count
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
          TripTime: TripTimeOfDay.MORNING,
          BusStop: busStop,
          TripNo: tripNo,
          Count: passengerCount,
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
          if (kDebugMode) {
            print('Created new CountTripList with count=$passengerCount');
          }
        }
      }
    } catch (e, st) {
      if (kDebugMode) print('Error updating count: $e\n$st');
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Helper ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // adjusts selected crowd level and corresponding count

  void selectCrowdLevel(int index) {
    if (!_selection) {
      // Only allow selection if not confirmed
      setState(() {
        if (selectedCrowdLevel == index) {
          selectedCrowdLevel = -1;
        } else {
          selectedCrowdLevel = index;
        }
        if (index == 0) {
          count = lessThanHalfFullCount;
        } else {
          if (index == 1) {
            count = moreOrHalfFullCount;
          } else {
            if (index == 2) {
              count = fullCount;
            }
          }
        }
      });
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Alert Dialogs ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // when trying to select Crowd level but no MRT or trip is selected

  void _showPleaseSelectTripDialog(BuildContext context) {
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
            'Please select an MRT Station, Trip Number, and Bus Stop before proceeding.',
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
  // shown when trying to press confirm before selecting a crowd level

  void _showPleaseSelectDialog(BuildContext context) {
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
            'Please select a Crowd Level before proceeding.',
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
  // shown when confirming selection

  void _showConfirmationDialog(String mrt, int tripNo, String busStop) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          actionsAlignment: MainAxisAlignment.center,
          title: Text(
            'Confirm Selection',
            style: TextStyle(
              fontSize: fontSizeHeading,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min, // only as big as needed
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min, // only as big as needed
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ROUTE:',
                        style: TextStyle(
                          fontSize: fontSizeMiniText,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'TRIP NO:',
                        style: TextStyle(
                          fontSize: fontSizeMiniText,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'TIME:',
                        style: TextStyle(
                          fontSize: fontSizeMiniText,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: fontSizeMiniText),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '$mrt - CAMPUS',
                        style: TextStyle(
                          fontSize: fontSizeMiniText,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      Text(
                        '$tripNo',
                        style: TextStyle(
                          fontSize: fontSizeMiniText,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      Text(
                        selectedMRT == 'CLE'
                            ? formatTime(morningTripsCLE[selectedTripNo! - 1])
                            : formatTime(morningTripsKAP[selectedTripNo! - 1]),
                        style: TextStyle(
                          fontSize: fontSizeMiniText,
                          fontWeight: FontWeight.normal,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: fontSizeMiniText),
              Text(
                'CROWD LEVEL:',
                style: TextStyle(
                  fontSize: fontSizeMiniText,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),

              SizedBox(height: fontSizeMiniText * 0.5),
              Container(
                width: fontSizeMiniText * 5,
                decoration: BoxDecoration(
                  color: selectedCrowdLevel == 0
                      ? Colors.green[300]
                      : selectedCrowdLevel == 1
                      ? Colors.orange[300]
                      : Colors.red[300],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selectedCrowdLevel == 0
                        ? Colors.green[800]!
                        : selectedCrowdLevel == 1
                        ? Colors.orange[800]!
                        : Colors.red[900]!,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Icon(
                      selectedCrowdLevel == 0
                          ? Icons.sentiment_satisfied_alt_rounded
                          : selectedCrowdLevel == 1
                          ? Icons.sentiment_neutral_outlined
                          : Icons.sentiment_dissatisfied_rounded,
                      color: selectedCrowdLevel == 0
                          ? Colors.green[800]
                          : selectedCrowdLevel == 1
                          ? Colors.orange[800]
                          : Colors.red[900],
                      size: fontSizeMiniText * 2,
                    ),
                    Text(
                      selectedCrowdLevel == 0
                          ? '<half'
                          : selectedCrowdLevel == 1
                          ? '>=half'
                          : 'full',
                      style: TextStyle(
                        color: selectedCrowdLevel == 0
                            ? Colors.green[800]
                            : selectedCrowdLevel == 1
                            ? Colors.orange[800]
                            : Colors.red[900],
                        fontSize: fontSizeMiniText,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: fontSizeMiniText),
            ],
          ),
          actions: [
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
                  'Cancel',
                  style: TextStyle(
                    fontSize: fontSizeMiniText,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedMRT = null;
                  // Reset all variables when selecting a different MRT station
                  selectedTripNo = null;
                  _selection = false;
                  selectedCrowdLevel = -1;
                });
                _updateCount(
                  isKAP: mrt == 'KAP',
                  tripNo: tripNo,
                  busStop: busStop,
                  passengerCount: count,
                );

                Navigator.of(context).pop(); // Close dialog
                confirmingProcess();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: Container(
                padding: EdgeInsetsGeometry.all(fontSizeText * 0.1),
                child: Text(
                  'Confirm',
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

  void confirmingProcess() {
    setState(() {
      loading = true;
    });

    // show loading dialog
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Center(
            child: Text(
              "Confirming...",
              style: TextStyle(
                color: Colors.blueGrey[800],
                fontSize: fontSizeText,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: fontSizeHeading,
                width: fontSizeHeading,
                child: CircularProgressIndicator(color: Colors.blueGrey[200]),
              ),
              SizedBox(height: fontSizeText),
            ],
          ),
        );
      },
    );

    // after 2s, close loading and show confirmation
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      // Always use the root navigator from the *original* context
      Navigator.of(context, rootNavigator: true).pop(); // close loading

      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) {
          return AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green[800],
                  size: fontSizeText,
                ),
                Text(
                  " Confirmed! ",
                  style: TextStyle(
                    fontSize: fontSizeText,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      );

      // after 2s, close confirmation
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop(); // close confirmation
        setState(() {
          loading = false;
        });
      });
    });
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
                            _selection = false;
                            selectedCrowdLevel = -1;
                          });
                        },
                        underline: SizedBox(),
                      ),
                    ),
                    Text(
                      ' - CAMPUS',
                      style: TextStyle(
                        fontSize: fontSizeText,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: fontSizeText),
                drawLine(),
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
                            overflow: TextOverflow
                                .ellipsis, // clips text if not fitting
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
                                        style: TextStyle(color: Colors.white),
                                        items:
                                            (selectedMRT == 'CLE'
                                                    ? List<int>.generate(
                                                        morningTripsCLE.length,
                                                        (i) => i + 1,
                                                      )
                                                    : selectedMRT == 'KAP'
                                                    ? List<int>.generate(
                                                        morningTripsKAP.length,
                                                        (i) => i + 1,
                                                      )
                                                    : [])
                                                .map<DropdownMenuItem<int>>((
                                                  value,
                                                ) {
                                                  final int tripNo =
                                                      value
                                                          as int; // cast dynamic → int

                                                  return DropdownMenuItem<int>(
                                                    value: tripNo,
                                                    child: Center(
                                                      child: Text(
                                                        tripNo.toString(),
                                                        style: TextStyle(
                                                          fontSize:
                                                              fontSizeText,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontFamily: 'Roboto',
                                                          color: Colors.white,
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
                                      style: TextStyle(color: Colors.white),
                                      items:
                                          (selectedMRT == 'CLE'
                                                  ? List<int>.generate(
                                                      morningTripsCLE.length,
                                                      (i) => i + 1,
                                                    )
                                                  : selectedMRT == 'KAP'
                                                  ? List<int>.generate(
                                                      morningTripsKAP.length,
                                                      (i) => i + 1,
                                                    )
                                                  : [])
                                              .map<DropdownMenuItem<int>>((
                                                value,
                                              ) {
                                                final int tripNo =
                                                    value
                                                        as int; // cast dynamic → int
                                                return DropdownMenuItem<int>(
                                                  value: tripNo,
                                                  child: Center(
                                                    child: Text(
                                                      tripNo.toString(),
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
                                              })
                                              .toList(),
                                      onChanged: (int? newValue) {
                                        setState(() {
                                          selectedTripNo = newValue;
                                          // reset selection
                                          _selection = false;
                                          selectedCrowdLevel = -1;
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
                              overflow: TextOverflow
                                  .ellipsis, // clips text if not fitting
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
                          Container(
                            height: fontSizeHeading * 1.5,

                            color: Colors.white,

                            child: Center(
                              child: Text(
                                selectedMRT == 'CLE'
                                    ? formatTime(
                                        morningTripsCLE[selectedTripNo! - 1],
                                      )
                                    : formatTime(
                                        morningTripsKAP[selectedTripNo! - 1],
                                      ),
                                style: TextStyle(
                                  fontSize: fontSizeText,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                          ),
                        if (!(selectedMRT != null && selectedTripNo != null))
                          SizedBox(
                            width: fontSizeHeading * 2,
                            height: fontSizeHeading * 1.5,
                            child: Center(
                              child: Text(
                                '--:--',
                                style: TextStyle(
                                  fontSize: fontSizeText,
                                  fontWeight: FontWeight.bold,
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
                Text(
                  'SELECT CROWD LEVEL',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSizeText,
                    fontWeight: FontWeight.normal,
                    fontFamily: 'Roboto',
                  ),
                ),

                SizedBox(height: fontSizeText),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!_selection) {
                          if (selectedMRT == null || selectedTripNo == null) {
                            _showPleaseSelectTripDialog(context);
                          } else {
                            selectCrowdLevel(0); // Less crowded
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
                              size: fontSizeHeading * 2,
                            ),
                            SizedBox(height: fontSizeMiniText * 0.2),
                            Text(
                              '< half',
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selectedCrowdLevel == 0
                                    ? Colors.green[800]
                                    : Colors.grey,
                                fontSize: fontSizeText,
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
                            _showPleaseSelectTripDialog(context);
                          } else {
                            selectCrowdLevel(1); // Crowded
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
                              size: fontSizeHeading * 2,
                            ),
                            SizedBox(height: fontSizeMiniText * 0.2),
                            Text(
                              '>= half',
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selectedCrowdLevel == 1
                                    ? Colors.orange[800]
                                    : Colors.grey,
                                fontSize: fontSizeText,
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
                            _showPleaseSelectTripDialog(context);
                          } else {
                            selectCrowdLevel(2); // Very Crowded
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
                              size: fontSizeHeading * 2,
                            ),
                            SizedBox(height: fontSizeMiniText * 0.2),
                            Text(
                              'full',
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selectedCrowdLevel == 2
                                    ? Colors.red[900]
                                    : Colors.grey,
                                fontSize: fontSizeText,
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

                SizedBox(height: fontSizeHeading),

                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selection == false &&
                          selectedCrowdLevel != -1 &&
                          selectedTripNo != null &&
                          selectedMRT != null &&
                          loading == false) {
                        _showConfirmationDialog(
                          selectedMRT!,
                          selectedTripNo!,
                          selectedMRT!,
                        );
                      } else {
                        _showPleaseSelectDialog(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: Container(
                      padding: EdgeInsetsGeometry.all(fontSizeText * 0.1),
                      child: Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: fontSizeText,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
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
