// Import service widgets for each section of the bus data page
import 'package:driver_10_updated/pages/screen_afternoon.dart';
import 'package:flutter/material.dart';

import '../pages/screen_morning.dart';
import '../utils/text_sizing.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- main page with appbar and two buttons to choose what service to track ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// MainPage class

// Main page
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  //////////////////////////////////////////////////////////////////////////////
  // Variables

  // Scroll controller for potential scrollable content (currently unused)
  final ScrollController controller = ScrollController();

  // Optional filters (currently unused in this snippet)
  String? selectedMRT;
  String? selectedBusStop;

  // Tracks which section is currently selected:
  // 1 = KAP Timing, 2 = CLE Timing, 3 = Bus Stops, 4 = News, 5 = Download/Table
  int selectedBox = 1;

  //////////////////////////////////////////////////////////////////////////////
  // dispose

  @override
  void dispose() {
    // Dispose of any controllers or resources here if needed
    super.dispose();
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Some functions ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Updates the selected section and triggers a rebuild
  void updateSelectedBox(int box) {
    setState(() {
      selectedBox = box;
    });
  }

  //////////////////////////////////////////////////////////////////////////////
  //  Section builder methods for cleaner code
  Widget _buildMorningScreen() => MorningPage();
  Widget _buildAfternoonScreen() => AfternoonPage();

  // Formats a DateTime as HH:mm
  String formatTime(DateTime time) {
    String hour = time.hour.toString().padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Formats a DateTime as HH:mm:ss
  String formatTimeSecond(DateTime time) {
    String hour = time.hour.toString().padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');
    String sec = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$sec';
  }

  //////////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// --- Main Build function ---
  /// //////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // === AppBar ===
      appBar: AppBar(
        toolbarHeight: TextSizing.fontSizeHeading(context) * 2.5,
        centerTitle: true,
        backgroundColor: Colors.black,

        // title
        title: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: TextSizing.fontSizeHeading(context),
                ),
                SizedBox(width: TextSizing.fontSizeMiniText(context) * 0.3),
                Flexible(
                  child: Text(
                    'MooBus Safety Operator',
                    maxLines: 1, //  limits to 1 lines
                    overflow:
                        TextOverflow.ellipsis, // clips text if not fitting
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: TextSizing.fontSizeHeading(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      // === Body ===
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          TextSizing.fontSizeMiniText(context),
          TextSizing.fontSizeMiniText(context),
          TextSizing.fontSizeMiniText(context),
          TextSizing.fontSizeMiniText(context),
        ),
        child: Column(
          children: [
            // === First Row: Timing selection buttons (KAP, CLE, Bus Stops) ===
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // KAP Timing Button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      updateSelectedBox(1); // Switch Morning
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      height: TextSizing.fontSizeHeading(context) * 1.75,
                      curve: Curves.easeOutCubic, // Smooth animation curve
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          15,
                        ), // Rounded corners
                        child: Container(
                          // Highlight if selected, otherwise light blue
                          color: selectedBox == 1
                              ? Colors.black
                              : Colors.blueGrey[100],
                          child: Padding(
                            padding: EdgeInsetsGeometry.fromLTRB(
                              TextSizing.fontSizeText(context) * 0.5,
                              0,
                              TextSizing.fontSizeText(context) * 0.5,
                              0,
                            ),
                            child: Center(
                              child: Text(
                                'Morning',
                                maxLines: 1, //  limits to 1 lines
                                overflow: TextOverflow
                                    .ellipsis, // clips text if not fitting
                                style: TextStyle(
                                  color: selectedBox == 1
                                      ? Colors.white
                                      : Colors.blueGrey[600],
                                  fontSize: TextSizing.fontSizeHeading(context),
                                  fontFamily: 'Roboto',
                                  fontWeight: selectedBox == 1
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  width: TextSizing.fontSizeMiniText(context),
                ), // Space between buttons
                // CLE Timing Button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      updateSelectedBox(2); // Switch to Afternoon
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      height: TextSizing.fontSizeHeading(context) * 1.75,
                      curve: Curves.easeOutCubic, // Smooth animation curve
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          15,
                        ), // Rounded corners
                        child: Container(
                          // Highlight if selected, otherwise light blue
                          color: selectedBox == 2
                              ? Colors.black
                              : Colors.blueGrey[100],
                          child: Padding(
                            padding: EdgeInsetsGeometry.fromLTRB(
                              TextSizing.fontSizeText(context) * 0.5,
                              0,
                              TextSizing.fontSizeText(context) * 0.5,
                              0,
                            ),
                            child: Center(
                              child: Text(
                                'Afternoon',
                                maxLines: 1, //  limits to 1 lines
                                overflow: TextOverflow
                                    .ellipsis, // clips text if not fitting
                                style: TextStyle(
                                  color: selectedBox == 2
                                      ? Colors.white
                                      : Colors.blueGrey[600],
                                  fontSize: TextSizing.fontSizeHeading(context),
                                  fontFamily: 'Roboto',
                                  fontWeight: selectedBox == 2
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(
              height: TextSizing.fontSizeMiniText(context),
            ), // Space before content section
            // === Content section based on selected item ===
            Expanded(
              child: IndexedStack(
                // Show the widget corresponding to the selectedBox value
                // selectedBox starts at 1, so subtract 1 for zero-based index
                index: selectedBox - 1,
                children: [
                  _buildMorningScreen(), // Index 0 → Morning
                  _buildAfternoonScreen(), // Index 1 → Afternoon
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
