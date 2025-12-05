import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

////////////////////////////////////////////////////////////////////////////////
/// ////////////////////////////////////////////////////////////////////////////
/// --- Text Sizing ---
/// ////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// TextSizing class
// used to determine sizing variables of layout,

class TextSizing {
  // variable that everything depends on, will be set at start by main.dart
  static late Size size;

  //////////////////////////////////////////////////////////////////////////////
  // function to set size

  static void setSize(BuildContext context) {
    size = MediaQuery.of(context).size;
    return;
  }

  //////////////////////////////////////////////////////////////////////////////
  // function that returns a bool based on if the device is a tablet or
  // in landscape mode

  static bool isTabletOrLandscapeMode(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final landscapeMode =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return shortestSide >= 600 || landscapeMode;
  }

  //////////////////////////////////////////////////////////////////////////////
  // will return if it is in landscape mode or not
  // used to show certain text
  // (checks it enough space as there is more horizontal space in landscape mode)

  static bool isLandscapeMode(BuildContext context) {
    final landscapeMode =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return landscapeMode;
  }

  //////////////////////////////////////////////////////////////////////////////
  // function to determine if device is a phone or a tablet based of the screen size

  static bool isTablet(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600;
  }

  //////////////////////////////////////////////////////////////////////////////
  // function to check for shortest side of device

  static double shortestSide(BuildContext context) {
    return (size.width < size.height ? size.width : size.height) * 2;
  }

  //////////////////////////////////////////////////////////////////////////////
  // function that returns a font size that can be used for text
  // on both android or iOS (iOS scaled everything smaller, which is why its factor is bigger)

  static double fontSizeText(
    BuildContext context, {
    double iphoneFactor = 0.02,
    double androidFactor = 0.015,
    double webFactor = 0.018, // new factor for web
    bool respectAccessibility = true,
  }) {
    double baseFactor;

    if (kIsWeb) {
      baseFactor = webFactor;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      baseFactor = androidFactor;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      baseFactor = iphoneFactor;
    } else {
      // fallback for desktop or other platforms
      baseFactor = 0.017;
    }

    double textFontSize = shortestSide(context) * baseFactor;

    if (respectAccessibility) {
      textFontSize = MediaQuery.of(context).textScaler.scale(textFontSize);
    }

    return textFontSize;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Returns a bigger font size based of font size of normal text

  static double fontSizeHeading(BuildContext context) {
    double headingFontSize = fontSizeText(context) * 1.7;
    return headingFontSize;
  }

  //////////////////////////////////////////////////////////////////////////////
  // returns a smaller font size based of font size of normal text

  static double fontSizeMiniText(BuildContext context) {
    double miniFontSize = fontSizeText(context) * 0.6;
    return miniFontSize;
  }
}
