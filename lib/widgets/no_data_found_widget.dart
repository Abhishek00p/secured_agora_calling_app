import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class NoDataFoundWidget extends StatelessWidget {
  const NoDataFoundWidget({this.message = 'No Data Found', super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/lottie/no_data_found.json',
            width: 200,
            height: 200,
            fit: BoxFit.fill,
            repeat: true, // Loops the animation
            reverse: false, // Doesn't play the animation in reverse
            animate: true, // Plays the animation automatically
          ),
          Text(message),
        ],
      ),
    );
  }
}
