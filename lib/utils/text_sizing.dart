import 'package:flutter/widgets.dart';

class TextSizing {
  static bool isTablet(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600;
  }

  static double widestSide(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height ? size.width : size.height;
  }

  static double fontSizeText(
    BuildContext context, {
    double phoneFactor = 0.03,
    double tabletFactor = 0.03,
    bool respectAccessibility = true,
  }) {
    final baseFactor = isTablet(context) ? tabletFactor : phoneFactor;
    double textFontSize = widestSide(context) * baseFactor;

    if (respectAccessibility) {
      textFontSize = MediaQuery.of(context).textScaler.scale(textFontSize);
    }

    return textFontSize;
  }

  /////////////////////////////////////////////////////////////////////
  // Returns a bigger font size

  static double fontSizeHeading(BuildContext context) {
    double headingFontSize = fontSizeText(context) * 1.3;
    return headingFontSize;
  }

  /////////////////////////////////////////////////////////////////////
  // returns a smaller font size

  static double fontSizeMiniText(BuildContext context) {
    double miniFontSize = fontSizeText(context) * 0.65;
    return miniFontSize;
  }
}
