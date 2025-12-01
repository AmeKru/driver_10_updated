import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../utils/text_sizing.dart';

class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SpinKitSpinningLines(
          color: Colors.grey,
          size: TextSizing.fontSizeHeading(context) * 5,
        ),
      ),
    );
  }
}

class LoadingScroll extends StatelessWidget {
  const LoadingScroll({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: TextSizing.fontSizeHeading(context)),
        Container(
          color: Colors.white,
          child: Center(
            child: SpinKitWave(
              color: Colors.grey,
              size: TextSizing.fontSizeHeading(context) * 3,
            ),
          ),
        ),
      ],
    );
  }
}
